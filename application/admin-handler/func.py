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

  GET    /v1/admin/metadata/objects/{owner}/{name}
  POST   /v1/admin/metadata/annotations

Krever permission: admin:users, admin:roles eller admin:metadata i JWT.

Sett LOG_LEVEL=DEBUG i miljøvariabler for detaljert logging.
"""

import base64
import io
import json
import logging
import os
import secrets
import smtplib
import zipfile
from email.mime.text import MIMEText
from typing import Optional
from metadata_sync import (
    build_ddl_statements,
    AnnotationSyncError,
    validate_object_reference,
)

import bcrypt
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


DB_USER = _require_env("DB_USER")
DB_DSN = _require_env("DB_DSN")
WALLET_SECRET_OCID = _require_env("WALLET_SECRET_OCID")
DBPASS_SECRET_OCID = _require_env("DBPASS_SECRET_OCID")
WALLETPASS_SECRET_OCID = _require_env("WALLETPASS_SECRET_OCID")
JWT_SECRET_OCID = _require_env("JWT_SECRET_OCID")
SMTP_PASSWORD_SECRET_OCID = _require_env("SMTP_PASSWORD_SECRET_OCID")
SMTP_HOST = _require_env("SMTP_HOST")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USER = _require_env("SMTP_USER")
EMAIL_SENDER = _require_env("EMAIL_SENDER")
FRONTEND_URL = _require_env("FRONTEND_URL")

_secrets_client: Optional[oci.secrets.SecretsClient] = None
_pool: Optional[oracledb.ConnectionPool] = None
_wallet_dir = "/tmp/wallet"
_jwt_secret: Optional[str] = None
_smtp_password: Optional[str] = None


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


def _get_smtp_password() -> str:
    global _smtp_password
    if _smtp_password is None:
        _smtp_password = _get_secret(SMTP_PASSWORD_SECRET_OCID).decode().strip()
    return _smtp_password


# ── Database ───────────────────────────────────────────────────


def _init_pool() -> oracledb.ConnectionPool:
    logger.info("Initialiserer connection pool")
    db_password = _get_secret(DBPASS_SECRET_OCID).decode().strip()
    wallet_password = _get_secret(WALLETPASS_SECRET_OCID).decode().strip()
    wallet_zip = _get_secret(WALLET_SECRET_OCID)

    logger.debug("Wallet zip størrelse: %d bytes", len(wallet_zip))

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


def _parse_path(ctx) -> list:
    headers = dict(ctx.Headers())
    url = headers.get("fn-http-request-url", headers.get("Fn-Http-Request-Url", ""))
    path = url.split("?")[0]
    parts = [p for p in path.split("/") if p]
    try:
        idx = parts.index("admin")
        return parts[idx + 1 :]
    except ValueError:
        return []


# ── E-post ─────────────────────────────────────────────────────


def _send_welcome_email(to_email: str, display_name: str, password: str) -> None:
    msg = MIMEText(
        f"Hei {display_name},\n\n"
        f"Du har fått tilgang til QueryChat.\n\n"
        f"Logg inn på: {FRONTEND_URL}/chat/\n\n"
        f"E-post:   {to_email}\n"
        f"Passord:  {password}\n\n"
        f"Du vil bli bedt om å bytte passord ved første innlogging.\n\n"
        f"Hilsen QueryChat",
        "plain",
        "utf-8",
    )
    msg["Subject"] = "Velkommen til QueryChat"
    msg["From"] = EMAIL_SENDER
    msg["To"] = to_email

    logger.info("Sender velkomst-e-post til: %s", to_email)
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30) as smtp:
        smtp.ehlo()
        smtp.starttls()
        smtp.ehlo()
        smtp.login(SMTP_USER, _get_smtp_password())
        smtp.sendmail(EMAIL_SENDER, to_email, msg.as_string())
    logger.info("Velkomst-e-post sendt")


# ── User handlers ──────────────────────────────────────────────


def _get_user_roles(conn: oracledb.Connection, user_id: str) -> list:
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
        return [
            {"id": row[0], "name": row[1], "description": row[2]}
            for row in cur.fetchall()
        ]


def _list_users(conn: oracledb.Connection, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, email, display_name, active, created_at, last_login
            FROM qc_users
            ORDER BY created_at DESC
            """)
        users = []
        for row in cur.fetchall():
            users.append(
                {
                    "id": row[0],
                    "email": row[1],
                    "display_name": row[2],
                    "active": row[3],
                    "created_at": str(row[4]) if row[4] else None,
                    "last_login": str(row[5]) if row[5] else None,
                }
            )

    for user in users:
        user["roles"] = _get_user_roles(conn, user["id"])

    logger.debug("Hentet %d brukere", len(users))
    return _resp(ctx, {"ok": True, "users": users})


def _get_user(conn: oracledb.Connection, user_id: str, ctx) -> fdk.response.Response:
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
        "id": row[0],
        "email": row[1],
        "display_name": row[2],
        "active": row[3],
        "created_at": str(row[4]) if row[4] else None,
        "last_login": str(row[5]) if row[5] else None,
    }
    user["roles"] = _get_user_roles(conn, user_id)
    return _resp(ctx, {"ok": True, "user": user})


def _create_user(conn: oracledb.Connection, body: dict, ctx) -> fdk.response.Response:
    email = body.get("email", "").strip().lower()
    display_name = body.get("display_name", "").strip()
    password = body.get("password") or secrets.token_hex(10)

    if not email or not display_name:
        return _resp(ctx, {"ok": False, "error": "Mangler e-post eller navn"}, 400)

    pw_hash = bcrypt.hashpw(password.encode(), bcrypt.gensalt()).decode()
    new_id = secrets.token_hex(16).upper()

    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO qc_users (id, email, display_name, pw_hash, active, must_change_password)
                VALUES (:id, :email, :name, :hash, 1, 1)
                """,
                id=new_id,
                email=email,
                name=display_name,
                hash=pw_hash,
            )
        conn.commit()
        logger.info("Opprettet bruker: %s", email)
    except oracledb.IntegrityError:
        return _resp(
            ctx, {"ok": False, "error": "E-postadressen er allerede i bruk"}, 409
        )

    try:
        _send_welcome_email(email, display_name, password)
    except Exception:
        logger.exception("Feil ved sending av velkomst-e-post til %s", email)

    return _resp(ctx, {"ok": True, "id": new_id}, 201)


def _update_user(
    conn: oracledb.Connection, user_id: str, body: dict, ctx
) -> fdk.response.Response:
    display_name = body.get("display_name")
    active = body.get("active")

    if display_name is None and active is None:
        return _resp(ctx, {"ok": False, "error": "Ingen felter å oppdatere"}, 400)

    with conn.cursor() as cur:
        if display_name is not None and active is not None:
            cur.execute(
                "UPDATE qc_users SET display_name = :name, active = :active WHERE id = :user_id",
                name=display_name,
                active=int(active),
                user_id=user_id,
            )
        elif display_name is not None:
            cur.execute(
                "UPDATE qc_users SET display_name = :name WHERE id = :user_id",
                name=display_name,
                user_id=user_id,
            )
        else:
            cur.execute(
                "UPDATE qc_users SET active = :active WHERE id = :user_id",
                active=int(active),
                user_id=user_id,
            )
    conn.commit()
    logger.info("Oppdatert bruker: %s", user_id)
    return _resp(ctx, {"ok": True})


def _deactivate_user(
    conn: oracledb.Connection, user_id: str, ctx
) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            "UPDATE qc_users SET active = 0 WHERE id = :user_id",
            user_id=user_id,
        )
    conn.commit()
    logger.info("Deaktivert bruker: %s", user_id)
    return _resp(ctx, {"ok": True})


def _add_user_role(
    conn: oracledb.Connection, user_id: str, body: dict, granted_by: str, ctx
) -> fdk.response.Response:
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
        logger.info("Lagt til rolle %s for bruker %s", role_id, user_id)
    except oracledb.IntegrityError:
        return _resp(
            ctx, {"ok": False, "error": "Bruker har allerede denne rollen"}, 409
        )

    return _resp(ctx, {"ok": True})


def _remove_user_role(
    conn: oracledb.Connection, user_id: str, role_id: str, ctx
) -> fdk.response.Response:
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
    logger.info("Fjernet rolle %s fra bruker %s", role_id, user_id)
    return _resp(ctx, {"ok": True})


def _admin_reset_password(
    conn: oracledb.Connection, user_id: str, body: dict, ctx
) -> fdk.response.Response:
    new_password = body.get("password") or secrets.token_hex(12)
    pw_hash = bcrypt.hashpw(new_password.encode(), bcrypt.gensalt()).decode()

    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE qc_users
            SET pw_hash = :hash, must_change_password = 1
            WHERE id = :user_id
            """,
            hash=pw_hash,
            user_id=user_id,
        )
        cur.execute(
            "UPDATE qc_refresh_tokens SET revoked = 1 WHERE user_id = :user_id",
            user_id=user_id,
        )
    conn.commit()
    logger.info("Passord tilbakestilt for bruker: %s", user_id)
    return _resp(ctx, {"ok": True})


# ── Role handlers ──────────────────────────────────────────────


def _list_roles(conn: oracledb.Connection, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute("SELECT id, name, description FROM qc_roles ORDER BY name")
        roles = [
            {"id": row[0], "name": row[1], "description": row[2]}
            for row in cur.fetchall()
        ]

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

    logger.debug("Hentet %d roller", len(roles))
    return _resp(ctx, {"ok": True, "roles": roles})


def _create_role(conn: oracledb.Connection, body: dict, ctx) -> fdk.response.Response:
    name = body.get("name", "").strip().lower()
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
        logger.info("Opprettet rolle: %s", name)
    except oracledb.IntegrityError:
        return _resp(ctx, {"ok": False, "error": "Rollenavn er allerede i bruk"}, 409)

    return _resp(ctx, {"ok": True, "id": new_id}, 201)


def _update_role(
    conn: oracledb.Connection, role_id: str, body: dict, ctx
) -> fdk.response.Response:
    description = body.get("description")
    if description is None:
        return _resp(ctx, {"ok": False, "error": "Ingen felter å oppdatere"}, 400)

    with conn.cursor() as cur:
        cur.execute(
            "UPDATE qc_roles SET description = :desc WHERE id = :role_id",
            desc=description,
            role_id=role_id,
        )
    conn.commit()
    logger.info("Oppdatert rolle: %s", role_id)
    return _resp(ctx, {"ok": True})


def _delete_role(conn: oracledb.Connection, role_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            "DELETE FROM qc_role_permissions WHERE role_id = :role_id", role_id=role_id
        )
        cur.execute(
            "DELETE FROM qc_user_roles WHERE role_id = :role_id", role_id=role_id
        )
        cur.execute("DELETE FROM qc_roles WHERE id = :role_id", role_id=role_id)
    conn.commit()
    logger.info("Slettet rolle: %s", role_id)
    return _resp(ctx, {"ok": True})


# ── Metadata handlers ──────────────────────────────────────────────


def _get_object_columns(conn: oracledb.Connection, owner: str, name: str) -> list:
    """Kolonner + datatype for objektet, fra ALL_TAB_COLUMNS."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name, data_type, data_length, nullable
            FROM all_tab_columns
            WHERE owner = :owner AND table_name = :name
            ORDER BY column_id
            """,
            owner=owner.upper(),
            name=name.upper(),
        )
        return [
            {
                "column_name": row[0],
                "data_type": row[1],
                "data_length": row[2],
                "nullable": row[3] == "Y",
            }
            for row in cur.fetchall()
        ]


def _get_object_comments(conn: oracledb.Connection, owner: str, name: str) -> dict:
    """
    Eksisterende COMMENT ON for objektet (tabell og kolonner), uavhengig
    av om de kommer fra qc_object_annotations eller andre migrasjoner
    (f.eks. 02_schema_comments.sql).

    Returnerer {"table": str|None, "columns": {col_name: str}}.
    """
    result = {"table": None, "columns": {}}
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT comments FROM all_tab_comments
            WHERE owner = :owner AND table_name = :name
            AND comments IS NOT NULL
            """,
            owner=owner.upper(),
            name=name.upper(),
        )
        row = cur.fetchone()
        if row:
            result["table"] = row[0]

        cur.execute(
            """
            SELECT column_name, comments FROM all_col_comments
            WHERE owner = :owner AND table_name = :name
            AND comments IS NOT NULL
            """,
            owner=owner.upper(),
            name=name.upper(),
        )
        for col_name, comment in cur.fetchall():
            result["columns"][col_name] = comment

    return result


def _get_object_annotations_usage(
    conn: oracledb.Connection, owner: str, name: str
) -> list:
    """
    Eksisterende ANNOTATIONS for objektet, fra USER_ANNOTATIONS_USAGE.
    Returnerer raa liste - en rad per (kolonne, annotasjonsnavn)-par.

    NB: USER_ANNOTATIONS_USAGE er skjema-scoped til DB_USER (querychat)
    og har ingen OWNER-kolonne (ALL_ANNOTATIONS_USAGE gav ORA-00904 i
    denne ADB-versjonen). For v1 er dette tilstrekkelig siden alle
    KI_GRUNNLAG_*-tabeller eies av QUERYCHAT selv. Hvis admin-metadata
    senere skal dekke objekter utenfor QUERYCHAT-skjemaet, maa dette
    revurderes (DBA_ANNOTATIONS_USAGE + utvidet privilegium).
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT column_name, annotation_name, annotation_value
            FROM user_annotations_usage
            WHERE object_name = :name
            ORDER BY column_name, annotation_name
            """,
            name=name.upper(),
        )
        return [
            {
                "column_name": row[0],
                "annotation_name": row[1],
                "annotation_value": row[2],
            }
            for row in cur.fetchall()
        ]


def _get_qc_annotation_rows(conn: oracledb.Connection, owner: str, name: str) -> list:
    """Alle qc_object_annotations-rader for objektet, alle statuser."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, column_name, sync_target, annotation_name,
                   annotation_value, notat_type, status, updated_by, updated_at
            FROM qc_object_annotations
            WHERE object_owner = :owner AND object_name = :name
            ORDER BY column_name, sync_target, annotation_name
            """,
            owner=owner.upper(),
            name=name.upper(),
        )
        return [
            {
                "id": row[0],
                "column_name": row[1],
                "sync_target": row[2],
                "annotation_name": row[3],
                "annotation_value": row[4],
                "notat_type": row[5],
                "status": row[6],
                "updated_by": row[7],
                "updated_at": str(row[8]) if row[8] else None,
            }
            for row in cur.fetchall()
        ]


def _get_metadata_object(
    conn: oracledb.Connection, owner: str, name: str, ctx
) -> fdk.response.Response:
    """
    GET /admin/metadata/objects/{owner}/{name}

    Returnerer kolonner, eksisterende COMMENT/ANNOTATIONS (fra
    dictionary-views) og qc_object_annotations-rader (alle statuser),
    slik at admin-UI-en kan vise "nåværende tilstand" + "våre
    redigerbare rader" side om side - jf. avsnitt 5.2.
    """
    columns = _get_object_columns(conn, owner, name)
    if not columns:
        return _resp(
            ctx,
            {
                "ok": False,
                "error": f"Objekt {owner}.{name} finnes ikke eller har ingen kolonner",
            },
            404,
        )

    return _resp(
        ctx,
        {
            "ok": True,
            "object_owner": owner.upper(),
            "object_name": name.upper(),
            "columns": columns,
            "existing_comments": _get_object_comments(conn, owner, name),
            "existing_annotations": _get_object_annotations_usage(conn, owner, name),
            "qc_annotations": _get_qc_annotation_rows(conn, owner, name),
        },
    )


def _upsert_annotation(
    conn: oracledb.Connection, body: dict, updated_by: str, ctx
) -> fdk.response.Response:
    """
    POST /admin/metadata/annotations

    Body (opprett): object_owner, object_name, column_name (valgfri),
                     sync_target, annotation_name (kun for ANNOTATION),
                     annotation_value, notat_type (kun for NONE),
                     status

    Body (oppdater): som over + id (eksisterende qc_object_annotations.id)

    Rekkefolge - viktig pga. DDL auto-commit i Oracle:
      1. Hent old_row (hvis id er gitt)
      2. Skriv/oppdater qc_object_annotations-raden (DML, ikke commitet)
      3. Generer og kjor DDL via apply_annotation (COMMENT/ANNOTATIONS)
      4. Commit

    Hvis DDL (steg 3) feiler, rulles steg 2 tilbake - men hvis DDL-en
    selv besto av flere setninger (DROP+ADD) og bare den forste lyktes,
    kan databasen vaere i en mellomtilstand som IKKE rulles tilbake
    (DDL auto-committer). Dette rapporteres til admin via "ddl_error"
    i svaret, slik at det kan handteres manuelt.
    """
    object_owner = body.get("object_owner", "").strip()
    object_name = body.get("object_name", "").strip()
    column_name = (body.get("column_name") or "").strip() or None
    sync_target = body.get("sync_target", "").strip().upper()
    annotation_name = (body.get("annotation_name") or "").strip() or None
    annotation_value = body.get("annotation_value", "").strip()
    notat_type = (body.get("notat_type") or "").strip() or None
    status = body.get("status", "AKTIV").strip().upper()
    annotation_id = (body.get("id") or "").strip() or None

    if not object_owner or not object_name:
        return _resp(
            ctx, {"ok": False, "error": "Mangler object_owner eller object_name"}, 400
        )

    new_row = {
        "object_owner": object_owner,
        "object_name": object_name,
        "column_name": column_name,
        "sync_target": sync_target,
        "annotation_name": annotation_name,
        "annotation_value": annotation_value,
        "notat_type": notat_type,
        "status": status,
    }

    old_row = None

    with conn.cursor() as cur:
        # 1. Hent old_row hvis dette er en oppdatering
        if annotation_id:
            cur.execute(
                """
                SELECT object_owner, object_name, column_name, sync_target,
                       annotation_name, annotation_value, notat_type, status
                FROM qc_object_annotations WHERE id = :id
                """,
                id=annotation_id,
            )
            row = cur.fetchone()
            if not row:
                return _resp(ctx, {"ok": False, "error": "Annotasjon ikke funnet"}, 404)
            old_row = {
                "object_owner": row[0],
                "object_name": row[1],
                "column_name": row[2],
                "sync_target": row[3],
                "annotation_name": row[4],
                "annotation_value": row[5],
                "notat_type": row[6],
                "status": row[7],
            }
            # Objekt/kolonne kan ikke endres ved oppdatering - kun
            # sync_target/annotation_name/annotation_value/notat_type/status.
            if (
                old_row["object_owner"] != object_owner.upper()
                or old_row["object_name"] != object_name.upper()
                or (old_row["column_name"] or None) != column_name
            ):
                return _resp(
                    ctx,
                    {
                        "ok": False,
                        "error": "object_owner/object_name/column_name kan ikke endres ved oppdatering",
                    },
                    400,
                )

        # 2. Valider + generer DDL FORST (uten aa kjore den), slik at
        #    valideringsfeil (ugyldig sync_target/annotation_name osv.)
        #    fanges som 400 FOR vi skriver til qc_object_annotations.
        try:
            statements = build_ddl_statements(new_row, old_row)
            validate_object_reference(cur, object_owner, object_name, column_name)
        except AnnotationSyncError as e:
            return _resp(ctx, {"ok": False, "error": str(e)}, 400)

        # 3. Skriv/oppdater qc_object_annotations (DML, ikke commitet)
        if annotation_id:
            cur.execute(
                """
                UPDATE qc_object_annotations
                SET sync_target = :sync_target,
                    annotation_name = :annotation_name,
                    annotation_value = :annotation_value,
                    notat_type = :notat_type,
                    status = :status,
                    updated_by = :updated_by,
                    updated_at = SYSTIMESTAMP
                WHERE id = :id
                """,
                sync_target=sync_target,
                annotation_name=annotation_name,
                annotation_value=annotation_value,
                notat_type=notat_type,
                status=status,
                updated_by=updated_by,
                id=annotation_id,
            )
        else:
            annotation_id = secrets.token_hex(16).upper()
            try:
                cur.execute(
                    """
                    INSERT INTO qc_object_annotations
                        (id, object_owner, object_name, column_name, sync_target,
                         annotation_name, annotation_value, notat_type, status, updated_by)
                    VALUES
                        (:id, :object_owner, :object_name, :column_name, :sync_target,
                         :annotation_name, :annotation_value, :notat_type, :status, :updated_by)
                    """,
                    id=annotation_id, object_owner=object_owner.upper(),
                    object_name=object_name.upper(), column_name=column_name,
                    sync_target=sync_target, annotation_name=annotation_name,
                    annotation_value=annotation_value, notat_type=notat_type,
                    status=status, updated_by=updated_by,
                )
            except oracledb.IntegrityError:
                return _resp(ctx, {
                    "ok": False,
                    "error": (
                        f"En annotasjon med samme type og navn finnes allerede for "
                        f"{object_name}.{column_name or '(tabellnivaa)'}. "
                        f"Bruk oppdatering (send id) i stedet for aa opprette ny."
                    )
                }, 400)

        # 4. Kjor DDL (COMMENT ON / ALTER TABLE ... ANNOTATIONS)
        ddl_error = None
        executed = []
        try:
            for stmt in statements:
                cur.execute(stmt)
                executed.append(stmt)
        except oracledb.DatabaseError as e:
            ddl_error = str(e)
            logger.exception("DDL feilet for annotasjon %s", annotation_id)

    if ddl_error:
        conn.rollback()
        return _resp(
            ctx,
            {
                "ok": False,
                "error": "DDL feilet - ingen endringer lagret i qc_object_annotations",
                "detail": ddl_error,
                "attempted_statements": statements,
                "executed_before_failure": executed,
            },
            500,
        )

    conn.commit()
    logger.info(
        "Annotasjon lagret: %s (%s.%s%s, %s/%s)",
        annotation_id,
        object_owner,
        object_name,
        f".{column_name}" if column_name else "",
        sync_target,
        status,
    )

    return _resp(ctx, {"ok": True, "id": annotation_id, "ddl": statements})


# ── Function handler ───────────────────────────────────────────


def handler(ctx, data: Optional[io.BytesIO] = None):
    try:
        payload = _verify_jwt(ctx)
    except PermissionError as e:
        return _resp(ctx, {"ok": False, "error": str(e)}, 401)
    except Exception:
        return _resp(ctx, {"ok": False, "error": "Ugyldig eller utløpt token"}, 401)

    headers = dict(ctx.Headers())
    method = headers.get("fn-http-method", headers.get("Fn-Http-Method", "GET")).upper()

    try:
        body = json.loads(data.getvalue()) if data and data.getvalue() else {}
    except Exception:
        return _resp(ctx, {"ok": False, "error": "Ugyldig JSON"}, 400)

    path = _parse_path(ctx)
    logger.debug("Path: %s, Method: %s", path, method)

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
                        # ── /admin/metadata ────────────────────────────────

            elif path[0] == "metadata":
                _require_permission(payload, "admin:metadata")

                if len(path) == 4 and path[1] == "objects":
                    owner, name = path[2], path[3]
                    if method == "GET":
                        return _get_metadata_object(conn, owner, name, ctx)

                elif len(path) == 2 and path[1] == "annotations":
                    if method == "POST":
                        return _upsert_annotation(conn, body, payload["sub"], ctx)

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
