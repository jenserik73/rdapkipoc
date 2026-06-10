"""
OCI Function: auth-handler

Håndterer alle autentiserings-endepunkter for QueryChat:
  - POST /v1/auth/login
  - POST /v1/auth/refresh
  - POST /v1/auth/logout
  - POST /v1/auth/forgot-password
  - POST /v1/auth/reset-password
  - GET  /v1/me
  - PUT  /v1/me/password

Ruting skjer via URL-path fra Fn-Http-Request-Url header.
"""

import base64
import io
import json
import logging
import os
import secrets
import smtplib
import zipfile
from datetime import datetime, timedelta, timezone
from email.mime.text import MIMEText

import bcrypt
import fdk.response
import jwt
import oci
import oracledb

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)


# ── konfigurasjon ──────────────────────────────────────────────

def _require_env(name: str) -> str:
    val = os.getenv(name)
    if not val:
        raise EnvironmentError(f"Mangler påkrevd miljøvariabel: {name}")
    return val

DB_USER                   = _require_env("DB_USER")
DB_DSN                    = _require_env("DB_DSN")
WALLET_SECRET_OCID        = _require_env("WALLET_SECRET_OCID")
DBPASS_SECRET_OCID        = _require_env("DBPASS_SECRET_OCID")
WALLETPASS_SECRET_OCID    = _require_env("WALLETPASS_SECRET_OCID")
JWT_SECRET_OCID           = _require_env("JWT_SECRET_OCID")
REFRESH_SECRET_OCID       = _require_env("REFRESH_SECRET_OCID")
SMTP_PASSWORD_SECRET_OCID = _require_env("SMTP_PASSWORD_SECRET_OCID")
SMTP_HOST                 = _require_env("SMTP_HOST")
SMTP_PORT                 = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER                 = _require_env("SMTP_USER")
EMAIL_SENDER              = _require_env("EMAIL_SENDER")
FRONTEND_URL              = _require_env("FRONTEND_URL")

JWT_EXPIRY_SECONDS   = 15 * 60
REFRESH_EXPIRY_DAYS  = 30
RESET_EXPIRY_MINUTES = 60

_secrets_client = None
_pool           = None
_wallet_dir     = "/tmp/wallet"
_jwt_secret     = None
_refresh_secret = None
_smtp_password  = None


# ── Vault ──────────────────────────────────────────────────────

def _get_secrets_client():
    global _secrets_client
    if _secrets_client is None:
        signer = oci.auth.signers.get_resource_principals_signer()
        _secrets_client = oci.secrets.SecretsClient({}, signer=signer)
    return _secrets_client


def _get_secret(ocid: str) -> bytes:
    bundle = _get_secrets_client().get_secret_bundle(secret_id=ocid).data
    return base64.b64decode(bundle.secret_bundle_content.content)


def _get_jwt_secret() -> str:
    global _jwt_secret
    if _jwt_secret is None:
        _jwt_secret = _get_secret(JWT_SECRET_OCID).decode().strip()
    return _jwt_secret


def _get_refresh_secret() -> str:
    global _refresh_secret
    if _refresh_secret is None:
        _refresh_secret = _get_secret(REFRESH_SECRET_OCID).decode().strip()
    return _refresh_secret


def _get_smtp_password() -> str:
    global _smtp_password
    if _smtp_password is None:
        _smtp_password = _get_secret(SMTP_PASSWORD_SECRET_OCID).decode().strip()
    return _smtp_password


# ── Database ───────────────────────────────────────────────────

def _init_pool():
    logger.info("Initialiserer connection pool")
    db_password     = _get_secret(DBPASS_SECRET_OCID).decode().strip()
    wallet_password = _get_secret(WALLETPASS_SECRET_OCID).decode().strip()
    wallet_zip      = _get_secret(WALLET_SECRET_OCID)

    os.makedirs(_wallet_dir, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(wallet_zip)) as zf:
        zf.extractall(_wallet_dir)

    return oracledb.create_pool(
        user=DB_USER,
        password=db_password,
        dsn=DB_DSN,
        min=1, max=5, increment=1,
        config_dir=_wallet_dir,
        wallet_location=_wallet_dir,
        wallet_password=wallet_password,
    )


def _get_pool():
    global _pool
    if _pool is None:
        _pool = _init_pool()
    return _pool


# ── JWT-helpers ────────────────────────────────────────────────

def _make_access_token(user: dict) -> str:
    now = datetime.now(timezone.utc)
    payload = {
        "sub":         user["id"],
        "email":       user["email"],
        "name":        user["display_name"],
        "roles":       user["roles"],
        "permissions": user["permissions"],
        "iat":         now,
        "exp":         now + timedelta(seconds=JWT_EXPIRY_SECONDS),
    }
    return jwt.encode(payload, _get_jwt_secret(), algorithm="HS256")


def _verify_access_token(token: str) -> dict:
    return jwt.decode(token, _get_jwt_secret(), algorithms=["HS256"])


def _get_auth_header(ctx) -> str:
    headers = dict(ctx.Headers())
    return headers.get("authorization", headers.get("Authorization", ""))


# ── DB-operasjoner ─────────────────────────────────────────────

def _get_user_by_email(conn, email: str) -> dict | None:
    logger.info("Henter bruker: %s", email)
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, email, display_name, pw_hash, active
            FROM qc_users
            WHERE email = :email
            """,
            email=email,
        )
        row = cur.fetchone()
        if not row:
            return None
        return {
            "id":           row[0],
            "email":        row[1],
            "display_name": row[2],
            "pw_hash":      row[3],
            "active":       row[4],
        }


def _get_user_roles_permissions(conn, user_id: str) -> tuple[list, list]:
    logger.info("Henter roller/rettigheter for: %s", user_id)
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT DISTINCT r.name
            FROM qc_user_roles ur
            JOIN qc_roles r ON ur.role_id = r.id
            WHERE ur.user_id = :user_id
            """,
            user_id=user_id,
        )
        roles = [row[0] for row in cur.fetchall()]

        cur.execute(
            """
            SELECT DISTINCT p.perm_resource || ':' || p.perm_action
            FROM qc_user_roles ur
            JOIN qc_role_permissions rp ON ur.role_id = rp.role_id
            JOIN qc_permissions p ON rp.permission_id = p.id
            WHERE ur.user_id = :user_id
            """,
            user_id=user_id,
        )
        permissions = [row[0] for row in cur.fetchall()]

    logger.info("Roller: %s", roles)
    return roles, permissions


def _update_last_login(conn, user_id: str):
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE qc_users SET last_login = SYSTIMESTAMP WHERE id = :user_id",
            user_id=user_id,
        )
    conn.commit()


def _store_refresh_token(conn, user_id: str, token: str, device_hint: str = None):
    expires = datetime.now(timezone.utc) + timedelta(days=REFRESH_EXPIRY_DAYS)
    logger.info("_store_refresh_token user_id type=%s value=%s", type(user_id), repr(user_id))
    logger.info("_store_refresh_token token type=%s", type(token))
    logger.info("_store_refresh_token hint type=%s value=%s", type(device_hint), repr(device_hint)[:50])
    logger.info("_store_refresh_token expires type=%s value=%s", type(expires), repr(expires))
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO qc_refresh_tokens (token, user_id, device_hint, expires_at)
            VALUES (:token, :user_id, :hint, :expires)
            """,
            token=token,
            user_id=user_id,
            hint=device_hint,
            expires=expires,
        )
    conn.commit()


def _get_refresh_token(conn, token: str) -> dict | None:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT user_id, expires_at, revoked
            FROM qc_refresh_tokens
            WHERE token = :token
            """,
            token=token,
        )
        row = cur.fetchone()
        if not row:
            return None
        return {
            "user_id":    row[0],
            "expires_at": row[1],
            "revoked":    row[2],
        }


def _revoke_refresh_token(conn, token: str):
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE qc_refresh_tokens SET revoked = 1 WHERE token = :token",
            token=token,
        )
    conn.commit()


def _revoke_all_user_tokens(conn, user_id: str):
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE qc_refresh_tokens SET revoked = 1 WHERE user_id = :user_id",
            user_id=user_id,
        )
    conn.commit()


def _get_user_by_id(conn, user_id: str) -> dict | None:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, email, display_name, active
            FROM qc_users WHERE id = :user_id
            """,
            user_id=user_id,
        )
        row = cur.fetchone()
        if not row:
            return None
        return {
            "id":           row[0],
            "email":        row[1],
            "display_name": row[2],
            "active":       row[3],
        }


# ── Email ──────────────────────────────────────────────────────

def _send_reset_email(to_email: str, reset_token: str):
    reset_url = f"{FRONTEND_URL}/#/reset?token={reset_token}"
    msg = MIMEText(
        f"Hei,\n\nDu har bedt om å tilbakestille passordet ditt for QueryChat.\n\n"
        f"Klikk på lenken under for å sette nytt passord (gyldig i {RESET_EXPIRY_MINUTES} minutter):\n\n"
        f"{reset_url}\n\n"
        f"Hvis du ikke ba om dette kan du ignorere denne e-posten.\n\n"
        f"Hilsen QueryChat",
        "plain",
        "utf-8",
    )
    msg["Subject"] = "Tilbakestill passord – QueryChat"
    msg["From"]    = EMAIL_SENDER
    msg["To"]      = to_email

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT) as smtp:
        smtp.starttls()
        smtp.login(SMTP_USER, _get_smtp_password())
        smtp.sendmail(EMAIL_SENDER, to_email, msg.as_string())


# ── Action-handlers ────────────────────────────────────────────

def _action_login(body: dict, ctx) -> fdk.response.Response:
    try:
        email    = body.get("email", "").strip().lower()
        password = body.get("password", "")

        if not email or not password:
            return _resp(ctx, {"ok": False, "error": "Mangler e-post eller passord"}, 400)

        with _get_pool().acquire() as conn:
            logger.info("STEG 1: Henter bruker")
            user = _get_user_by_email(conn, email)
            logger.info("STEG 2: Bruker hentet: %s", user is not None)

            if not user or not user["active"]:
                return _resp(ctx, {"ok": False, "error": "Ugyldig e-post eller passord"}, 401)

            logger.info("STEG 3: Sjekker passord")
            pw_hash = user["pw_hash"]
            if isinstance(pw_hash, oracledb.LOB):
                pw_hash = pw_hash.read()
            if isinstance(pw_hash, str):
                pw_hash = pw_hash.encode()

            if not bcrypt.checkpw(password.encode(), pw_hash):
                return _resp(ctx, {"ok": False, "error": "Ugyldig e-post eller passord"}, 401)

            logger.info("STEG 4: Henter roller")
            roles, permissions = _get_user_roles_permissions(conn, user["id"])
            user["roles"]       = roles
            user["permissions"] = permissions
            logger.info("STEG 5: Lager tokens")
            access_token  = _make_access_token(user)
            refresh_token = secrets.token_hex(32)

            logger.info("STEG 6: Lagrer refresh token")
            headers     = dict(ctx.Headers())
            user_agent  = headers.get("user-agent", "")
            if isinstance(user_agent, list):
                user_agent = user_agent[0] if user_agent else ""
            device_hint = user_agent[:255]
            _store_refresh_token(conn, user["id"], refresh_token, device_hint)
            logger.info("STEG 7: Oppdaterer last_login")
            _update_last_login(conn, user["id"])
            logger.info("STEG 8: Ferdig")
            return _resp(ctx, {
                "ok":            True,
                "access_token":  access_token,
                "refresh_token": refresh_token,
                "user": {
                    "email":        user["email"],
                    "display_name": user["display_name"],
                    "roles":        roles,
                    "permissions":  permissions,
                },
            })

    except oracledb.DatabaseError as e:
        logger.exception("Database-feil i login")
        return _resp(ctx, {"ok": False, "error": "Databasefeil", "detail": str(e)}, 500)
    except Exception as e:
        logger.exception("Uventet feil i login")
        return _resp(ctx, {"ok": False, "error": str(e), "type": type(e).__name__}, 500)


def _action_refresh(body: dict, ctx) -> fdk.response.Response:
    try:
        refresh_token = body.get("refresh_token", "").strip()
        if not refresh_token:
            return _resp(ctx, {"ok": False, "error": "Mangler refresh_token"}, 400)

        with _get_pool().acquire() as conn:
            stored = _get_refresh_token(conn, refresh_token)

            if not stored or stored["revoked"]:
                return _resp(ctx, {"ok": False, "error": "Ugyldig refresh token"}, 401)

            if stored["expires_at"].replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
                return _resp(ctx, {"ok": False, "error": "Refresh token utløpt"}, 401)

            _revoke_refresh_token(conn, refresh_token)

            user = _get_user_by_id(conn, stored["user_id"])
            if not user or not user["active"]:
                return _resp(ctx, {"ok": False, "error": "Bruker ikke funnet eller deaktivert"}, 401)

            roles, permissions = _get_user_roles_permissions(conn, user["id"])
            user["roles"]       = roles
            user["permissions"] = permissions

            new_access_token  = _make_access_token(user)
            new_refresh_token = secrets.token_hex(32)

            headers     = dict(ctx.Headers())
            user_agent  = headers.get("user-agent", "")
            if isinstance(user_agent, list):
                user_agent = user_agent[0] if user_agent else ""
            device_hint = user_agent[:255]
            _store_refresh_token(conn, user["id"], new_refresh_token, device_hint)

        return _resp(ctx, {
            "ok":            True,
            "access_token":  new_access_token,
            "refresh_token": new_refresh_token,
        })

    except oracledb.DatabaseError as e:
        logger.exception("Database-feil i refresh")
        return _resp(ctx, {"ok": False, "error": "Databasefeil", "detail": str(e)}, 500)
    except Exception as e:
        logger.exception("Uventet feil i refresh")
        return _resp(ctx, {"ok": False, "error": str(e), "type": type(e).__name__}, 500)


def _action_logout(body: dict, ctx) -> fdk.response.Response:
    try:
        refresh_token = body.get("refresh_token", "").strip()
        if not refresh_token:
            return _resp(ctx, {"ok": True})

        with _get_pool().acquire() as conn:
            _revoke_refresh_token(conn, refresh_token)

        return _resp(ctx, {"ok": True})

    except Exception as e:
        logger.exception("Feil i logout")
        return _resp(ctx, {"ok": False, "error": str(e)}, 500)


def _action_forgot_password(body: dict, ctx) -> fdk.response.Response:
    try:
        email = body.get("email", "").strip().lower()
        if not email:
            return _resp(ctx, {"ok": False, "error": "Mangler e-post"}, 400)

        with _get_pool().acquire() as conn:
            user = _get_user_by_email(conn, email)
            if user and user["active"]:
                reset_token = secrets.token_hex(32)
                expires     = datetime.now(timezone.utc) + timedelta(minutes=RESET_EXPIRY_MINUTES)
                with conn.cursor() as cur:
                    cur.execute(
                        """
                        INSERT INTO qc_password_resets (token, user_id, expires_at)
                        VALUES (:token, :user_id, :expires)
                        """,
                        token=reset_token,
                        user_id=user["id"],
                        expires=expires,
                    )
                conn.commit()
                try:
                    _send_reset_email(email, reset_token)
                except Exception:
                    logger.exception("Feil ved sending av reset-epost")

        return _resp(ctx, {"ok": True, "message": "Hvis e-postadressen finnes vil du motta en lenke"})

    except oracledb.DatabaseError as e:
        logger.exception("Database-feil i forgot-password")
        return _resp(ctx, {"ok": False, "error": "Databasefeil", "detail": str(e)}, 500)
    except Exception as e:
        logger.exception("Uventet feil i forgot-password")
        return _resp(ctx, {"ok": False, "error": str(e), "type": type(e).__name__}, 500)


def _action_reset_password(body: dict, ctx) -> fdk.response.Response:
    try:
        token        = body.get("token", "").strip()
        new_password = body.get("password", "")

        if not token or not new_password:
            return _resp(ctx, {"ok": False, "error": "Mangler token eller passord"}, 400)

        if len(new_password) < 8:
            return _resp(ctx, {"ok": False, "error": "Passordet må være minst 8 tegn"}, 400)

        with _get_pool().acquire() as conn:
            with conn.cursor() as cur:
                cur.execute(
                    """
                    SELECT user_id, expires_at, used
                    FROM qc_password_resets
                    WHERE token = :token
                    """,
                    token=token,
                )
                row = cur.fetchone()

            if not row:
                return _resp(ctx, {"ok": False, "error": "Ugyldig token"}, 400)

            user_id, expires_at, used = row
            if used:
                return _resp(ctx, {"ok": False, "error": "Token allerede brukt"}, 400)

            if expires_at.replace(tzinfo=timezone.utc) < datetime.now(timezone.utc):
                return _resp(ctx, {"ok": False, "error": "Token utløpt"}, 400)

            pw_hash = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()

            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE qc_users SET pw_hash = :hash WHERE id = :user_id",
                    hash=pw_hash,
                    user_id=user_id,
                )
                cur.execute(
                    "UPDATE qc_password_resets SET used = 1 WHERE token = :token",
                    token=token,
                )
            conn.commit()
            _revoke_all_user_tokens(conn, user_id)

        return _resp(ctx, {"ok": True, "message": "Passord oppdatert"})

    except oracledb.DatabaseError as e:
        logger.exception("Database-feil i reset-password")
        return _resp(ctx, {"ok": False, "error": "Databasefeil", "detail": str(e)}, 500)
    except Exception as e:
        logger.exception("Uventet feil i reset-password")
        return _resp(ctx, {"ok": False, "error": str(e), "type": type(e).__name__}, 500)


def _action_me_get(ctx) -> fdk.response.Response:
    try:
        auth = _get_auth_header(ctx)
        if not auth.startswith("Bearer "):
            return _resp(ctx, {"ok": False, "error": "Ikke autentisert"}, 401)
        try:
            payload = _verify_access_token(auth.removeprefix("Bearer ").strip())
        except jwt.ExpiredSignatureError:
            return _resp(ctx, {"ok": False, "error": "Token utløpt"}, 401)
        except Exception:
            return _resp(ctx, {"ok": False, "error": "Ugyldig token"}, 401)

        return _resp(ctx, {
            "ok":   True,
            "user": {
                "email":        payload["email"],
                "display_name": payload["name"],
                "roles":        payload["roles"],
                "permissions":  payload["permissions"],
            },
        })
    except Exception as e:
        logger.exception("Uventet feil i me-get")
        return _resp(ctx, {"ok": False, "error": str(e)}, 500)


def _action_me_put(body: dict, ctx) -> fdk.response.Response:
    try:
        auth = _get_auth_header(ctx)
        if not auth.startswith("Bearer "):
            return _resp(ctx, {"ok": False, "error": "Ikke autentisert"}, 401)
        try:
            payload = _verify_access_token(auth.removeprefix("Bearer ").strip())
        except jwt.ExpiredSignatureError:
            return _resp(ctx, {"ok": False, "error": "Token utløpt"}, 401)
        except Exception:
            return _resp(ctx, {"ok": False, "error": "Ugyldig token"}, 401)

        old_password = body.get("old_password", "")
        new_password = body.get("new_password", "")

        if not old_password or not new_password:
            return _resp(ctx, {"ok": False, "error": "Mangler gammelt eller nytt passord"}, 400)

        if len(new_password) < 8:
            return _resp(ctx, {"ok": False, "error": "Passordet må være minst 8 tegn"}, 400)

        with _get_pool().acquire() as conn:
            user = _get_user_by_email(conn, payload["email"])
            if not user:
                return _resp(ctx, {"ok": False, "error": "Bruker ikke funnet"}, 404)

            pw_hash = user["pw_hash"]
            if isinstance(pw_hash, oracledb.LOB):
                pw_hash = pw_hash.read()
            if isinstance(pw_hash, str):
                pw_hash = pw_hash.encode()

            if not bcrypt.checkpw(old_password.encode(), pw_hash):
                return _resp(ctx, {"ok": False, "error": "Feil gammelt passord"}, 401)

            new_hash = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE qc_users SET pw_hash = :hash WHERE id = :user_id",
                    hash=new_hash,
                    user_id=user["id"],
                )
            conn.commit()

        return _resp(ctx, {"ok": True, "message": "Passord oppdatert"})

    except oracledb.DatabaseError as e:
        logger.exception("Database-feil i me-put")
        return _resp(ctx, {"ok": False, "error": "Databasefeil", "detail": str(e)}, 500)
    except Exception as e:
        logger.exception("Uventet feil i me-put")
        return _resp(ctx, {"ok": False, "error": str(e), "type": type(e).__name__}, 500)


# ── Function handler ───────────────────────────────────────────

def handler(ctx, data: io.BytesIO = None):
    try:
        headers = dict(ctx.Headers())
        url     = headers.get("fn-http-request-url", headers.get("Fn-Http-Request-Url", ""))
        method  = headers.get("fn-http-method", headers.get("Fn-Http-Method", "GET")).upper()

        logger.info("URL: %s, Method: %s", url, method)

        action = ""
        if "/auth/login" in url:
            action = "login"
        elif "/auth/refresh" in url:
            action = "refresh"
        elif "/auth/logout" in url:
            action = "logout"
        elif "/auth/forgot-password" in url:
            action = "forgot-password"
        elif "/auth/reset-password" in url:
            action = "reset-password"

        try:
            body = json.loads(data.getvalue()) if data and data.getvalue() else {}
        except Exception:
            return _resp(ctx, {"ok": False, "error": "Ugyldig JSON"}, 400)

        if action == "login":
            return _action_login(body, ctx)
        elif action == "refresh":
            return _action_refresh(body, ctx)
        elif action == "logout":
            return _action_logout(body, ctx)
        elif action == "forgot-password":
            return _action_forgot_password(body, ctx)
        elif action == "reset-password":
            return _action_reset_password(body, ctx)
        else:
            if method == "GET":
                return _action_me_get(ctx)
            elif method == "PUT":
                return _action_me_put(body, ctx)

        return _resp(ctx, {"ok": False, "error": "Ukjent endepunkt"}, 400)

    except Exception as e:
        logger.exception("Ubehandlet feil i handler")
        return _resp(ctx, {"ok": False, "error": str(e), "type": type(e).__name__}, 500)


def _resp(ctx, data: dict, status: int = 200) -> fdk.response.Response:
    return fdk.response.Response(
        ctx,
        response_data=json.dumps(data, ensure_ascii=False),
        headers={"Content-Type": "application/json; charset=utf-8"},
        status_code=status,
    )