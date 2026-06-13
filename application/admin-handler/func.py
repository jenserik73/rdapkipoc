"""
OCI Function: admin-handler

Håndterer admin-endepunkter for QueryChat:
  GET    /v1/admin/users
  POST   /v1/admin/users
  GET    /v1/admin/users/{id}
  PUT    /v1/admin/users/{id}
  DELETE /v1/admin/users/{id}
  POST   /v1/admin/users/{id}/roles
  DELETE /v1/admin/users/{id}/roles/{role_id}
  POST   /v1/admin/users/{id}/reset-password

  GET    /v1/admin/roles
  POST   /v1/admin/roles
  PUT    /v1/admin/roles/{id}
  DELETE /v1/admin/roles/{id}

Krever permission: admin:users eller admin:roles i JWT.
"""

import base64
import io
import json
import logging
import os
import secrets
import zipfile

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

DB_USER                = _require_env("DB_USER")
DB_DSN                 = _require_env("DB_DSN")
WALLET_SECRET_OCID     = _require_env("WALLET_SECRET_OCID")
DBPASS_SECRET_OCID     = _require_env("DBPASS_SECRET_OCID")
WALLETPASS_SECRET_OCID = _require_env("WALLETPASS_SECRET_OCID")
JWT_SECRET_OCID        = _require_env("JWT_SECRET_OCID")

_secrets_client = None
_pool           = None
_wallet_dir     = "/tmp/wallet"
_jwt_secret     = None


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


# ── Database ───────────────────────────────────────────────────

def _init_pool():
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


# ── JWT-validering ─────────────────────────────────────────────

def _verify_jwt(ctx) -> dict:
    headers = dict(ctx.Headers())
    auth    = headers.get("authorization", headers.get("Authorization", ""))
    if not auth.startswith("Bearer "):
        raise PermissionError("Mangler Authorization-header")
    token = auth.removeprefix("Bearer ").strip()
    return jwt.decode(token, _get_jwt_secret(), algorithms=["HS256"])


def _require_permission(payload: dict, permission: str):
    if permission not in payload.get("permissions", []):
        raise PermissionError(f"Mangler rettighet: {permission}")


# ── Path-parsing ───────────────────────────────────────────────

def _parse_path(ctx) -> list[str]:
    headers = dict(ctx.Headers())
    url     = headers.get("fn-http-request-url", headers.get("Fn-Http-Request-Url", ""))
    path    = url.split("?")[0]
    parts   = [p for p in path.split("/") if p]
    try:
        idx = parts.index("admin")
        return parts[idx + 1:]
    except ValueError:
        return []


# ── User handlers ──────────────────────────────────────────────

def _get_user_roles(conn, user_id: str) -> list:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT r.id, r.name, r.description
            FROM qc_user_roles ur
            JOIN qc_roles r ON ur.role_id = r.id
            WHERE ur.user_id = :user_id
            ORDER BY r.name
            """,
            user_id=user_id,
        )
        return [{"id": row[0], "name": row[1], "description": row[2]}
                for row in cur.fetchall()]


def _list_users(conn, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, email, display_name, active, created_at, last_login
            FROM qc_users
            ORDER BY created_at DESC
            """
        )
        users = []
        for row in cur.fetchall():
            users.append({
                "id":           row[0],
                "email":        row[1],
                "display_name": row[2],
                "active":       row[3],
                "created_at":   str(row[4]) if row[4] else None,
                "last_login":   str(row[5]) if row[5] else None,
            })

    for user in users:
        user["roles"] = _get_user_roles(conn, user["id"])

    return _resp(ctx, {"ok": True, "users": users})


def _get_user(conn, user_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, email, display_name, active, created_at, last_login
            FROM qc_users WHERE id = :user_id
            """,
            user_id=user_id,
        )
        row = cur.fetchone()

    if not row:
        return _resp(ctx, {"ok": False, "error": "Bruker ikke funnet"}, 404)

    user = {
        "id":           row[0],
        "email":        row[1],
        "display_name": row[2],
        "active":       row[3],
        "created_at":   str(row[4]) if row[4] else None,
        "last_login":   str(row[5]) if row[5] else None,
    }
    user["roles"] = _get_user_roles(conn, user_id)
    return _resp(ctx, {"ok": True, "user": user})


def _create_user(conn, body: dict, ctx) -> fdk.response.Response:
    email        = body.get("email", "").strip().lower()
    display_name = body.get("display_name", "").strip()
    password     = body.get("password", secrets.token_hex(16))

    if not email or not display_name:
        return _resp(ctx, {"ok": False, "error": "Mangler e-post eller navn"}, 400)

    pw_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    new_id  = secrets.token_hex(16).upper()

    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO qc_users (id, email, display_name, pw_hash, active)
                VALUES (:id, :email, :name, :hash, 1)
                """,
                id=new_id,
                email=email,
                name=display_name,
                hash=pw_hash,
            )
        conn.commit()
    except oracledb.IntegrityError:
        return _resp(ctx, {"ok": False, "error": "E-postadressen er allerede i bruk"}, 409)

    return _resp(ctx, {"ok": True, "id": new_id}, 201)


def _update_user(conn, user_id: str, body: dict, ctx) -> fdk.response.Response:
    display_name = body.get("display_name")
    active       = body.get("active")

    if display_name is None and active is None:
        return _resp(ctx, {"ok": False, "error": "Ingen felter å oppdatere"}, 400)

    with conn.cursor() as cur:
        if display_name is not None and active is not None:
            cur.execute(
                "UPDATE qc_users SET display_name = :name, active = :active WHERE id = :user_id",
                name=display_name, active=int(active), user_id=user_id,
            )
        elif display_name is not None:
            cur.execute(
                "UPDATE qc_users SET display_name = :name WHERE id = :user_id",
                name=display_name, user_id=user_id,
            )
        else:
            cur.execute(
                "UPDATE qc_users SET active = :active WHERE id = :user_id",
                active=int(active), user_id=user_id,
            )
    conn.commit()
    return _resp(ctx, {"ok": True})


def _deactivate_user(conn, user_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE qc_users SET active = 0 WHERE id = :user_id",
            user_id=user_id,
        )
    conn.commit()
    return _resp(ctx, {"ok": True})


def _add_user_role(conn, user_id: str, body: dict, granted_by: str, ctx) -> fdk.response.Response:
    role_id = body.get("role_id", "").strip()
    if not role_id:
        return _resp(ctx, {"ok": False, "error": "Mangler role_id"}, 400)

    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO qc_user_roles (user_id, role_id, granted_by)
                VALUES (:user_id, :role_id, :granted_by)
                """,
                user_id=user_id,
                role_id=role_id,
                granted_by=granted_by,
            )
        conn.commit()
    except oracledb.IntegrityError:
        return _resp(ctx, {"ok": False, "error": "Bruker har allerede denne rollen"}, 409)

    return _resp(ctx, {"ok": True})


def _remove_user_role(conn, user_id: str, role_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            """
            DELETE FROM qc_user_roles
            WHERE user_id = :user_id AND role_id = :role_id
            """,
            user_id=user_id,
            role_id=role_id,
        )
    conn.commit()
    return _resp(ctx, {"ok": True})


def _admin_reset_password(conn, user_id: str, body: dict, ctx) -> fdk.response.Response:
    new_password = body.get("password", secrets.token_hex(12))
    pw_hash = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()

    with conn.cursor() as cur:
        cur.execute(
            "UPDATE qc_users SET pw_hash = :hash WHERE id = :user_id",
            hash=pw_hash, user_id=user_id,
        )
        cur.execute(
            "UPDATE qc_refresh_tokens SET revoked = 1 WHERE user_id = :user_id",
            user_id=user_id,
        )
    conn.commit()
    return _resp(ctx, {"ok": True, "temporary_password": new_password})


# ── Role handlers ──────────────────────────────────────────────

def _list_roles(conn, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute("SELECT id, name, description FROM qc_roles ORDER BY name")
        roles = [{"id": row[0], "name": row[1], "description": row[2]}
                 for row in cur.fetchall()]

        for role in roles:
            cur.execute(
                """
                SELECT p.id, p.perm_resource, p.perm_action
                FROM qc_role_permissions rp
                JOIN qc_permissions p ON rp.permission_id = p.id
                WHERE rp.role_id = :role_id
                ORDER BY p.perm_resource, p.perm_action
                """,
                role_id=role["id"],
            )
            role["permissions"] = [
                {"id": row[0], "resource": row[1], "action": row[2]}
                for row in cur.fetchall()
            ]

    return _resp(ctx, {"ok": True, "roles": roles})


def _create_role(conn, body: dict, ctx) -> fdk.response.Response:
    name        = body.get("name", "").strip().lower()
    description = body.get("description", "")

    if not name:
        return _resp(ctx, {"ok": False, "error": "Mangler rollenavn"}, 400)

    new_id = secrets.token_hex(16).upper()

    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO qc_roles (id, name, description)
                VALUES (:id, :name, :desc)
                """,
                id=new_id,
                name=name,
                desc=description,
            )
        conn.commit()
    except oracledb.IntegrityError:
        return _resp(ctx, {"ok": False, "error": "Rollenavn er allerede i bruk"}, 409)

    return _resp(ctx, {"ok": True, "id": new_id}, 201)


def _update_role(conn, role_id: str, body: dict, ctx) -> fdk.response.Response:
    description = body.get("description")
    if description is None:
        return _resp(ctx, {"ok": False, "error": "Ingen felter å oppdatere"}, 400)

    with conn.cursor() as cur:
        cur.execute(
            "UPDATE qc_roles SET description = :desc WHERE id = :role_id",
            desc=description, role_id=role_id,
        )
    conn.commit()
    return _resp(ctx, {"ok": True})


def _delete_role(conn, role_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute("DELETE FROM qc_role_permissions WHERE role_id = :role_id", role_id=role_id)
        cur.execute("DELETE FROM qc_user_roles WHERE role_id = :role_id", role_id=role_id)
        cur.execute("DELETE FROM qc_roles WHERE id = :role_id", role_id=role_id)
    conn.commit()
    return _resp(ctx, {"ok": True})


# ── Function handler ───────────────────────────────────────────

def handler(ctx, data: io.BytesIO = None):
    try:
        payload = _verify_jwt(ctx)
    except PermissionError as e:
        return _resp(ctx, {"ok": False, "error": str(e)}, 401)
    except Exception:
        return _resp(ctx, {"ok": False, "error": "Ugyldig eller utløpt token"}, 401)

    headers = dict(ctx.Headers())
    method  = headers.get("fn-http-method", headers.get("Fn-Http-Method", "GET")).upper()

    try:
        body = json.loads(data.getvalue()) if data and data.getvalue() else {}
    except Exception:
        return _resp(ctx, {"ok": False, "error": "Ugyldig JSON"}, 400)

    path = _parse_path(ctx)
    logger.info("Path: %s, Method: %s", path, method)

    if not path:
        return _resp(ctx, {"ok": False, "error": "Ukjent endepunkt"}, 404)

    try:
        with _get_pool().acquire() as conn:

            # ── /admin/users ───────────────────────────────────
            if path[0] == "users":
                _require_permission(payload, "admin:users")

                if len(path) == 1:
                    if method == "GET":
                        return _list_users(conn, ctx)
                    elif method == "POST":
                        return _create_user(conn, body, ctx)

                elif len(path) == 2:
                    user_id = path[1]
                    if method == "GET":
                        return _get_user(conn, user_id, ctx)
                    elif method == "PUT":
                        return _update_user(conn, user_id, body, ctx)
                    elif method == "DELETE":
                        return _deactivate_user(conn, user_id, ctx)

                elif len(path) == 3 and path[2] == "roles":
                    user_id = path[1]
                    if method == "POST":
                        return _add_user_role(conn, user_id, body, payload["sub"], ctx)

                elif len(path) == 4 and path[2] == "roles":
                    user_id = path[1]
                    role_id = path[3]
                    if method == "DELETE":
                        return _remove_user_role(conn, user_id, role_id, ctx)

                elif len(path) == 3 and path[2] == "reset-password":
                    user_id = path[1]
                    if method == "POST":
                        return _admin_reset_password(conn, user_id, body, ctx)

            # ── /admin/roles ───────────────────────────────────
            elif path[0] == "roles":
                _require_permission(payload, "admin:roles")

                if len(path) == 1:
                    if method == "GET":
                        return _list_roles(conn, ctx)
                    elif method == "POST":
                        return _create_role(conn, body, ctx)

                elif len(path) == 2:
                    role_id = path[1]
                    if method == "PUT":
                        return _update_role(conn, role_id, body, ctx)
                    elif method == "DELETE":
                        return _delete_role(conn, role_id, ctx)

    except PermissionError as e:
        return _resp(ctx, {"ok": False, "error": str(e)}, 403)
    except oracledb.DatabaseError as e:
        logger.exception("Database-feil")
        return _resp(ctx, {"ok": False, "error": "Databasefeil", "detail": str(e)}, 500)
    except Exception as e:
        logger.exception("Uventet feil")
        return _resp(ctx, {"ok": False, "error": str(e), "type": type(e).__name__}, 500)

    return _resp(ctx, {"ok": False, "error": "Ukjent endepunkt"}, 404)


def _resp(ctx, data: dict, status: int = 200) -> fdk.response.Response:
    return fdk.response.Response(
        ctx,
        response_data=json.dumps(data, ensure_ascii=False),
        headers={"Content-Type": "application/json; charset=utf-8"},
        status_code=status,
    )