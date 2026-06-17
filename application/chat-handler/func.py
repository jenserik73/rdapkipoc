"""
OCI Function: chat-handler

Håndterer chat-samtaler og meldinger for QueryChat.

  GET    /v1/chats                      – list samtaler for innlogget bruker
  POST   /v1/chats                      – opprett ny samtale
  DELETE /v1/chats/{id}                 – slett samtale (cascade messages)
  GET    /v1/chats/{id}/messages        – hent meldinger
  POST   /v1/chats/{id}/messages        – legg til melding
  PUT    /v1/chats/{id}/title           – oppdater tittel

Krever gyldig JWT i Authorization-header.
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


# ── Path-parsing ───────────────────────────────────────────────


def _parse_path(ctx) -> list[str]:
    """
    Returnerer path-segmenter etter /v1/chats/.
    F.eks. /v1/chats/abc123/messages → ['abc123', 'messages']
    """
    headers = dict(ctx.Headers())
    url = headers.get("fn-http-request-url", headers.get("Fn-Http-Request-Url", ""))
    path = url.split("?")[0]
    parts = [p for p in path.split("/") if p]
    try:
        idx = parts.index("chats")
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


def _raw_to_hex(raw) -> str:
    """RAW(16) bytes/bytearray → lowercase hex-streng."""
    return bytes(raw).hex()


def _hex_to_raw(hex_str: str) -> bytes:
    """32-tegns hex-streng → bytes for binding mot RAW(16)."""
    return bytes.fromhex(hex_str)


def _is_valid_hex_id(s: str) -> bool:
    try:
        bytes.fromhex(s)
        return len(s) == 32
    except ValueError:
        return False


# ── Session-handlers ───────────────────────────────────────────


def _list_chats(conn: oracledb.Connection, user_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT RAWTOHEX(id), title,
                   created_at,
                   updated_at
            FROM   qc_chat_sessions
            WHERE  user_id = :user_id
            ORDER  BY updated_at DESC
            FETCH  FIRST 100 ROWS ONLY
            """,
            user_id=user_id,
        )
        sessions = [
            {"id": r[0], "title": r[1], "created_at": r[2], "updated_at": r[3]}
            for r in cur.fetchall()
        ]
    logger.debug("Hentet %d samtaler for bruker %s", len(sessions), user_id)
    return _resp(ctx, {"ok": True, "sessions": sessions})


def _create_chat(conn: oracledb.Connection, user_id: str, body: dict, ctx) -> fdk.response.Response:
    title = (body.get("title") or "Ny samtale")[:255]
    with conn.cursor() as cur:
        cur.execute(
            """
            INSERT INTO qc_chat_sessions (user_id, title)
            VALUES (:user_id, :chat_title)
            """,
            user_id=user_id,
            chat_title=title,
        )
        # Hent ny rad (SYS_GUID generert av Oracle)
        cur.execute(
            """
            SELECT RAWTOHEX(id),
                   created_at,
                   updated_at
            FROM   qc_chat_sessions
            WHERE  user_id = :user_id
            ORDER  BY created_at DESC
            FETCH  FIRST 1 ROW ONLY
            """,
            user_id=user_id,
        )
        row = cur.fetchone()
    conn.commit()
    logger.info("Opprettet samtale %s for bruker %s", row[0], user_id)
    return _resp(ctx, {
        "ok": True,
        "id": row[0], "title": title,
        "created_at": row[1], "updated_at": row[2],
    }, 201)


def _delete_chat(conn: oracledb.Connection, user_id: str, session_id: str, ctx) -> fdk.response.Response:
    sid = _hex_to_raw(session_id)
    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM qc_chat_sessions WHERE id = :sid AND user_id = :u_id",
            sid=sid, u_id=user_id,
        )
        if cur.fetchone()[0] == 0:
            return _resp(ctx, {"ok": False, "error": "Samtale ikke funnet"}, 404)
        cur.execute(
            "DELETE FROM qc_chat_sessions WHERE id = :sid AND user_id = :u_id",
            sid=sid, u_id=user_id,
        )
    conn.commit()
    logger.info("Slettet samtale %s", session_id)
    return _resp(ctx, {"ok": True, "deleted": session_id})


# ── Message-handlers ───────────────────────────────────────────


def _get_messages(conn: oracledb.Connection, user_id: str, session_id: str, ctx) -> fdk.response.Response:
    sid = _hex_to_raw(session_id)
    with conn.cursor() as cur:
        cur.execute(
            "SELECT COUNT(*) FROM qc_chat_sessions WHERE id = :sid AND user_id = :u_id",
            sid=sid, u_id=user_id,
        )
        if cur.fetchone()[0] == 0:
            return _resp(ctx, {"ok": False, "error": "Samtale ikke funnet"}, 404)
        cur.execute(
            """
            SELECT RAWTOHEX(id), role, content,
                   created_at
            FROM   qc_chat_messages
            WHERE  session_id = :sid
            ORDER  BY created_at ASC
            """,
            sid=sid,
        )
        messages = [
            {"id": r[0], "role": r[1], "content": r[2], "created_at": r[3]}
            for r in cur.fetchall()
        ]
    logger.debug("Hentet %d meldinger for session %s", len(messages), session_id)
    return _resp(ctx, {"ok": True, "messages": messages})


def _add_message(conn: oracledb.Connection, user_id: str, session_id: str, body: dict, ctx) -> fdk.response.Response:
    sid  = _hex_to_raw(session_id)
    role = body.get("role", "user")
    if role not in ("user", "assistant", "error"):
        return _resp(ctx, {"ok": False, "error": "Ugyldig role – bruk user | assistant | error"}, 400)
    content = (body.get("content") or "").strip()
    if not content:
        return _resp(ctx, {"ok": False, "error": "content er påkrevd"}, 400)

    with conn.cursor() as cur:
        cur.execute(
            "SELECT title FROM qc_chat_sessions WHERE id = :sid AND user_id = :u_id",
            sid=sid, u_id=user_id,
        )
        row = cur.fetchone()
        if row is None:
            return _resp(ctx, {"ok": False, "error": "Samtale ikke funnet"}, 404)
        current_title = row[0]

        cur.execute(
            """
            INSERT INTO qc_chat_messages (session_id, role, content)
            VALUES (:sid, :msg_role, :content)
            """,
            sid=sid, msg_role=role, content=content,
        )
        cur.execute(
            "UPDATE qc_chat_sessions SET updated_at = SYSTIMESTAMP WHERE id = :sid",
            sid=sid,
        )
        # Auto-tittel fra første brukermelding
        if role == "user" and current_title == "Ny samtale":
            cur.execute(
                "UPDATE qc_chat_sessions SET title = :new_title WHERE id = :sid",
                new_title=content[:80], sid=sid,
            )

        cur.execute(
            """
            SELECT RAWTOHEX(id), created_at
            FROM   qc_chat_messages
            WHERE  session_id = :sid
            ORDER  BY created_at DESC
            FETCH  FIRST 1 ROW ONLY
            """,
            sid=sid,
        )
        new_row = cur.fetchone()

    conn.commit()
    logger.debug("Lagt til melding (%s) i session %s", role, session_id)
    return _resp(ctx, {
        "ok": True,
        "id": new_row[0], "session_id": session_id,
        "role": role, "content": content,
        "created_at": new_row[1],
    }, 201)


def _update_title(conn: oracledb.Connection, user_id: str, session_id: str, body: dict, ctx) -> fdk.response.Response:
    sid   = _hex_to_raw(session_id)
    title = (body.get("title") or "").strip()[:255]
    if not title:
        return _resp(ctx, {"ok": False, "error": "title er påkrevd"}, 400)

    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE qc_chat_sessions
            SET    title = :chat_title, updated_at = SYSTIMESTAMP
            WHERE  id = :sid AND user_id = :u_id
            """,
            chat_title=title, sid=sid, u_id=user_id,
        )
        if cur.rowcount == 0:
            return _resp(ctx, {"ok": False, "error": "Samtale ikke funnet"}, 404)
    conn.commit()
    logger.info("Oppdatert tittel for session %s", session_id)
    return _resp(ctx, {"ok": True, "id": session_id, "title": title})


# ── Function handler ───────────────────────────────────────────


def handler(ctx, data: Optional[io.BytesIO] = None):
    try:
        payload = _verify_jwt(ctx)
    except PermissionError as e:
        return _resp(ctx, {"ok": False, "error": str(e)}, 401)
    except Exception:
        return _resp(ctx, {"ok": False, "error": "Ugyldig eller utløpt token"}, 401)

    user_id = payload.get("sub")
    if not user_id:
        return _resp(ctx, {"ok": False, "error": "Token mangler sub"}, 401)

    method = _get_method(ctx)

    try:
        body = json.loads(data.getvalue()) if data and data.getvalue() else {}
    except Exception:
        return _resp(ctx, {"ok": False, "error": "Ugyldig JSON"}, 400)

    path = _parse_path(ctx)
    logger.debug("Path: %s, Method: %s, User: %s", path, method, user_id)

    try:
        with _get_pool().acquire() as conn:

            # GET /v1/chats  |  POST /v1/chats
            if len(path) == 0:
                if method == "GET":
                    return _list_chats(conn, user_id, ctx)
                if method == "POST":
                    return _create_chat(conn, user_id, body, ctx)

            # DELETE /v1/chats/{id}
            elif len(path) == 1:
                sid = path[0]
                if not _is_valid_hex_id(sid):
                    return _resp(ctx, {"ok": False, "error": "Ugyldig session-ID"}, 400)
                if method == "DELETE":
                    return _delete_chat(conn, user_id, sid, ctx)

            # GET /v1/chats/{id}/messages  |  POST /v1/chats/{id}/messages
            # PUT /v1/chats/{id}/title
            elif len(path) == 2:
                sid, sub = path[0], path[1]
                if not _is_valid_hex_id(sid):
                    return _resp(ctx, {"ok": False, "error": "Ugyldig session-ID"}, 400)

                if sub == "messages":
                    if method == "GET":
                        return _get_messages(conn, user_id, sid, ctx)
                    if method == "POST":
                        return _add_message(conn, user_id, sid, body, ctx)

                elif sub == "title":
                    if method == "PUT":
                        return _update_title(conn, user_id, sid, body, ctx)

    except oracledb.DatabaseError as e:
        logger.exception("Database-feil")
        return _resp(ctx, {"ok": False, "error": "Databasefeil", "detail": str(e)}, 500)
    except Exception as e:
        logger.exception("Uventet feil")
        return _resp(ctx, {"ok": False, "error": str(e), "type": type(e).__name__}, 500)

    return _resp(ctx, {"ok": False, "error": "Ukjent endepunkt"}, 404)
