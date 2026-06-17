"""
OCI Function: profile-handler

Administrerer brukerinnstillinger for QueryChat.
Krever permission: admin:profiles i JWT.

  GET    /v1/admin/profiles/settings         – alle nøkler med defaults og metadata
  GET    /v1/admin/profiles/{user_id}        – merged view for én bruker
  PUT    /v1/admin/profiles/{user_id}/{key}  – sett verdi
  DELETE /v1/admin/profiles/{user_id}/{key}  – tilbakestill til standard

Sett LOG_LEVEL=DEBUG i miljøvariabler for detaljert logging.
"""

import base64
import io
import json
import logging
import os
import zipfile
from typing import Optional

import fdk.response
import jwt
import oci
import oracledb

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO))
logger = logging.getLogger(__name__)


# ── Konfigurasjon ──────────────────────────────────────────────


def _require_env(name: str) -> str:
    val = os.getenv(name)
    if not val:
        raise EnvironmentError(f"Mangler påkrevd miljøvariabel: {name}")
    return val


DB_USER                = _require_env("DB_USER")
DB_DSN                 = _require_env("DB_DSN")
WALLET_SECRET_OCID     = _require_env("WALLET_SECRET_OCID")
DBPASS_SECRET_OCID     = _require_env("DBPASS_SECRET_OCID")
WALLETPASS_SECRET_OCID = _require_env("WALLETPASS_SECRET_OCID")
JWT_SECRET_OCID        = _require_env("JWT_SECRET_OCID")

_secrets_client: Optional[oci.secrets.SecretsClient] = None
_pool:           Optional[oracledb.ConnectionPool]   = None
_wallet_dir = "/tmp/wallet"
_jwt_secret: Optional[str] = None


# ── Vault ──────────────────────────────────────────────────────


def _get_secrets_client() -> oci.secrets.SecretsClient:
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


# ── Database ───────────────────────────────────────────────────


def _init_pool() -> oracledb.ConnectionPool:
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
        min=1,
        max=5,
        increment=1,
        config_dir=_wallet_dir,
        wallet_location=_wallet_dir,
        wallet_password=wallet_password,
    )


def _get_pool() -> oracledb.ConnectionPool:
    global _pool
    if _pool is None:
        _pool = _init_pool()
    return _pool


# ── JWT ────────────────────────────────────────────────────────


def _verify_jwt(ctx) -> dict:
    headers = dict(ctx.Headers())
    auth = headers.get("authorization", headers.get("Authorization", ""))
    if not auth.startswith("Bearer "):
        raise PermissionError("Mangler Authorization-header")
    token = auth.removeprefix("Bearer ").strip()
    return jwt.decode(token, _get_jwt_secret(), algorithms=["HS256"])


def _require_permission(payload: dict, permission: str) -> None:
    if permission not in payload.get("permissions", []):
        raise PermissionError(f"Mangler rettighet: {permission}")


# ── Path-parsing ───────────────────────────────────────────────


def _parse_path(ctx) -> list[str]:
    """
    Returnerer path-segmenter etter /v1/admin/profiles/.
    F.eks. /v1/admin/profiles/abc123/ui.theme → ['abc123', 'ui.theme']
    """
    headers = dict(ctx.Headers())
    url = headers.get("fn-http-request-url", headers.get("Fn-Http-Request-Url", ""))
    path = url.split("?")[0]
    parts = [p for p in path.split("/") if p]
    try:
        idx = parts.index("profiles")
        return parts[idx + 1:]
    except ValueError:
        return []


def _get_method(ctx) -> str:
    headers = dict(ctx.Headers())
    return headers.get("fn-http-method", headers.get("Fn-Http-Method", "GET")).upper()


# ── Hjelp ──────────────────────────────────────────────────────


def _resp(ctx, data: dict, status: int = 200) -> fdk.response.Response:
    return fdk.response.Response(
        ctx,
        response_data=json.dumps(data, ensure_ascii=False, default=str),
        headers={"Content-Type": "application/json; charset=utf-8"},
        status_code=status,
    )


# ── Handlers ───────────────────────────────────────────────────


def _list_settings_schema(conn: oracledb.Connection, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT key, value, description, category
            FROM   qc_settings_defaults
            ORDER  BY category, key
            """
        )
        settings = [
            {"key": r[0], "default": r[1], "description": r[2], "category": r[3]}
            for r in cur.fetchall()
        ]
    return _resp(ctx, {"ok": True, "settings": settings})


def _get_user_settings(conn: oracledb.Connection, user_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            "SELECT id, email, display_name FROM qc_users WHERE id = :p_uid",
            p_uid=user_id,
        )
        user_row = cur.fetchone()
        if not user_row:
            return _resp(ctx, {"ok": False, "error": f"Bruker {user_id} ikke funnet"}, 404)

        cur.execute(
            """
            SELECT d.key, d.value AS default_value, d.description, d.category,
                   u.value AS user_value,
                   u.updated_at
            FROM   qc_settings_defaults d
            LEFT   JOIN qc_user_settings u
                   ON  u.key = d.key AND u.user_id = :p_uid
            ORDER  BY d.category, d.key
            """,
            p_uid=user_id,
        )
        settings = [
            {
                "key":         r[0],
                "default":     r[1],
                "description": r[2],
                "category":    r[3],
                "value":       r[4] if r[4] is not None else r[1],
                "overridden":  r[4] is not None,
                "updated_at":  r[5],
            }
            for r in cur.fetchall()
        ]

    return _resp(ctx, {
        "ok":       True,
        "user_id":  user_id,
        "email":    user_row[1],
        "display_name": user_row[2],
        "settings": settings,
    })


def _set_user_setting(conn: oracledb.Connection, user_id: str, key: str, body: dict, ctx) -> fdk.response.Response:
    value = body.get("value")
    if value is None:
        return _resp(ctx, {"ok": False, "error": "value er påkrevd"}, 400)
    value = str(value)[:1000]

    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM qc_settings_defaults WHERE key = :p_key",
            p_key=key,
        )
        if cur.fetchone()[0] == 0:
            return _resp(ctx, {"ok": False, "error": f"Ukjent innstillingsnøkkel: {key}"}, 400)

        cur.execute(
            "SELECT COUNT(*) FROM qc_users WHERE id = :p_uid",
            p_uid=user_id,
        )
        if cur.fetchone()[0] == 0:
            return _resp(ctx, {"ok": False, "error": f"Bruker {user_id} ikke funnet"}, 404)

        cur.execute(
            """
            MERGE INTO qc_user_settings t
            USING (SELECT :p_uid AS user_id, :p_key AS key FROM dual) s
            ON (t.user_id = s.user_id AND t.key = s.key)
            WHEN MATCHED THEN
                UPDATE SET value = :value, updated_at = SYSTIMESTAMP
            WHEN NOT MATCHED THEN
                INSERT (user_id, key, value) VALUES (:p_uid, :p_key, :value)
            """,
            p_uid=user_id, p_key=key, value=value,
        )
    conn.commit()
    logger.info("Satt %s=%s for bruker %s", key, value, user_id)
    return _resp(ctx, {"ok": True, "user_id": user_id, "key": key, "value": value})


def _reset_user_setting(conn: oracledb.Connection, user_id: str, key: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            "DELETE FROM qc_user_settings WHERE user_id = :p_uid AND key = :p_key",
            p_uid=user_id, p_key=key,
        )
        deleted = cur.rowcount
    conn.commit()
    logger.info("Tilbakestilt %s for bruker %s (slettet: %d)", key, user_id, deleted)
    return _resp(ctx, {
        "ok":      True,
        "user_id": user_id,
        "key":     key,
        "reset":   deleted > 0,
        "message": "Tilbakestilt til standardverdi" if deleted > 0 else "Ingen overstyring å slette",
    })


# ── Function handler ───────────────────────────────────────────


def handler(ctx, data: Optional[io.BytesIO] = None):
    try:
        payload = _verify_jwt(ctx)
    except PermissionError as e:
        return _resp(ctx, {"ok": False, "error": str(e)}, 401)
    except Exception:
        return _resp(ctx, {"ok": False, "error": "Ugyldig eller utløpt token"}, 401)

    method = _get_method(ctx)

    try:
        body = json.loads(data.getvalue()) if data and data.getvalue() else {}
    except Exception:
        return _resp(ctx, {"ok": False, "error": "Ugyldig JSON"}, 400)

    path = _parse_path(ctx)
    logger.debug("Path: %s, Method: %s", path, method)

    try:
        with _get_pool().acquire() as conn:
            _require_permission(payload, "admin:profiles")

            # GET /v1/admin/profiles/settings
            if len(path) == 1 and path[0] == "settings" and method == "GET":
                return _list_settings_schema(conn, ctx)

            # GET /v1/admin/profiles/{user_id}
            elif len(path) == 1 and method == "GET":
                return _get_user_settings(conn, path[0], ctx)

            # PUT /v1/admin/profiles/{user_id}/{key}
            # DELETE /v1/admin/profiles/{user_id}/{key}
            elif len(path) == 2:
                user_id, key = path[0], path[1]
                if method == "PUT":
                    return _set_user_setting(conn, user_id, key, body, ctx)
                if method == "DELETE":
                    return _reset_user_setting(conn, user_id, key, ctx)

    except PermissionError as e:
        return _resp(ctx, {"ok": False, "error": str(e)}, 403)
    except oracledb.DatabaseError as e:
        logger.exception("Database-feil")
        return _resp(ctx, {"ok": False, "error": "Databasefeil", "detail": str(e)}, 500)
    except Exception as e:
        logger.exception("Uventet feil")
        return _resp(ctx, {"ok": False, "error": str(e), "type": type(e).__name__}, 500)

    return _resp(ctx, {"ok": False, "error": "Ukjent endepunkt"}, 404)
