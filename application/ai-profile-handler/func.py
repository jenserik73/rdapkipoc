"""
OCI Function: ai-profile-handler

Administrerer DBMS_CLOUD_AI-profiler for QueryChat: CRUD på profilkatalogen
(med faktisk synk mot ADB via DBMS_CLOUD_AI), brukertilgang, og brukerens
eget profilvalg.

Admin-ruter (krever admin:aiprofiles):
  GET    /v1/admin/ai-profiles                      – list alle profiler
  POST   /v1/admin/ai-profiles                       – opprett profil (kjører CREATE_PROFILE i ADB)
  GET    /v1/admin/ai-profiles/{id}                  – hent én profil
  PUT    /v1/admin/ai-profiles/{id}                  – oppdater profil (kjører UPDATE_ATTRIBUTES i ADB)
  DELETE /v1/admin/ai-profiles/{id}                  – slett profil (kjører DROP_PROFILE i ADB)
  GET    /v1/admin/ai-profiles/{id}/access            – list brukere med tilgang
  PUT    /v1/admin/ai-profiles/{id}/access/{user_id}  – gi bruker tilgang
  DELETE /v1/admin/ai-profiles/{id}/access/{user_id}  – fjern brukers tilgang

Bruker-ruter (krever kun gyldig JWT):
  GET    /v1/me/ai-profiles         – list profiler innlogget bruker har tilgang til
  GET    /v1/me/ai-profile          – hent aktiv profil
  PUT    /v1/me/ai-profile          – sett aktiv profil (må ha tilgang)

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

VALID_OBJECT_SCHEMA = "QUERYCHAT"  # eneste skjema admin kan velge objekter fra


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
        min=1, max=5, increment=1,
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
    Returnerer hele path-segmentlisten etter domenet, f.eks.
    /v1/admin/ai-profiles/abc/access/def -> ['admin','ai-profiles','abc','access','def']
    /v1/me/ai-profile -> ['me','ai-profile']
    """
    headers = dict(ctx.Headers())
    url = headers.get("fn-http-request-url", headers.get("Fn-Http-Request-Url", ""))
    path = url.split("?")[0]
    parts = [p for p in path.split("/") if p]
    try:
        idx = parts.index("v1")
        return parts[idx + 1:]
    except ValueError:
        return parts


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


def _bool_to_flag(val) -> str:
    return "Y" if val else "N"


def _flag_to_bool(val: str) -> bool:
    return val == "Y"


def _row_to_profile(r: tuple) -> dict:
    """Mapper en rad fra qc_ai_profiles til dict. Forventer kolonnerekkefølgen i SELECT under."""
    object_list = json.loads(r[16].read() if hasattr(r[16], "read") else (r[16] or "[]"))
    return {
        "id":                  r[0],
        "profile_name":        r[1],
        "display_name":        r[2],
        "description":         r[3],
        "provider":            r[4],
        "credential_name":     r[5],
        "model":               r[6],
        "oci_compartment_id":  r[7],
        "region":              r[8],
        "max_tokens":          r[9],
        "temperature":         float(r[10]) if r[10] is not None else None,
        "enable_sources":      _flag_to_bool(r[11]),
        "annotations":         _flag_to_bool(r[12]),
        "comments":            _flag_to_bool(r[13]),
        "case_sensitive_values": _flag_to_bool(r[14]),
        "source_language":     r[15],
        "object_list":         object_list,
        "is_active":           _flag_to_bool(r[17]),
        "is_default":          _flag_to_bool(r[18]),
        "sync_status":         r[19],
        "sync_error":          r[20],
        "created_at":          r[21],
        "updated_at":          r[22],
    }


_PROFILE_SELECT_COLUMNS = """
    id, profile_name, display_name, description,
    provider, credential_name, model,
    oci_compartment_id, region,
    max_tokens, temperature,
    enable_sources, annotations, comments, case_sensitive_values,
    source_language, object_list,
    is_active, is_default, sync_status, sync_error,
    created_at, updated_at
"""


# ── DBMS_CLOUD_AI-synk ───────────────────────────────────────────


def _build_attributes_json(p: dict) -> str:
    """Bygger JSON-attributes-strengen DBMS_CLOUD_AI.CREATE_PROFILE/UPDATE_ATTRIBUTES forventer."""
    attrs = {
        "provider": p["provider"],
        "credential_name": p["credential_name"],
        "model": p["model"],
        "object_list": p["object_list"],
        "max_tokens": p["max_tokens"],
        "temperature": p["temperature"],
        "enable_sources": "true" if p["enable_sources"] else "false",
        "annotations": "true" if p["annotations"] else "false",
        "comments": "true" if p["comments"] else "false",
        "case_sensitive_values": "true" if p["case_sensitive_values"] else "false",
        "source_language": p["source_language"],
        "target_language": p["target_language"],
    }
    if p.get("oci_compartment_id"):
        attrs["oci_compartment_id"] = p["oci_compartment_id"]
    if p.get("region"):
        attrs["region"] = p["region"]
    return json.dumps(attrs)


def _sync_create_profile(conn: oracledb.Connection, p: dict) -> Optional[str]:
    """Kjører DBMS_CLOUD_AI.CREATE_PROFILE. Returnerer feilmelding ved feil, ellers None."""
    attrs_json = _build_attributes_json(p)
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                BEGIN
                  DBMS_CLOUD_AI.CREATE_PROFILE(
                    profile_name => :pname,
                    attributes   => :attrs
                  );
                END;
                """,
                pname=p["profile_name"], attrs=attrs_json,
            )
        conn.commit()
        return None
    except oracledb.DatabaseError as e:
        logger.exception("CREATE_PROFILE feilet for %s", p["profile_name"])
        return str(e)


def _sync_update_profile(conn: oracledb.Connection, p: dict) -> Optional[str]:
    """
    DBMS_CLOUD_AI.UPDATE_ATTRIBUTES krever attribute_name/attribute_value par,
    ikke en hel JSON-blob. Vi oppdaterer attributtene én etter én. Enklere og
    mer robust er å DROP + CREATE på nytt, siden profilen uansett ikke har
    annen tilstand enn konfigurasjonen selv.
    """
    try:
        with conn.cursor() as cur:
            cur.execute(
                "BEGIN DBMS_CLOUD_AI.DROP_PROFILE(profile_name => :pname, force => true); END;",
                pname=p["profile_name"],
            )
        conn.commit()
    except oracledb.DatabaseError:
        pass  # profilen fantes kanskje ikke ennå - ok, vi oppretter den under

    return _sync_create_profile(conn, p)


def _sync_drop_profile(conn: oracledb.Connection, profile_name: str) -> Optional[str]:
    try:
        with conn.cursor() as cur:
            cur.execute(
                "BEGIN DBMS_CLOUD_AI.DROP_PROFILE(profile_name => :pname, force => true); END;",
                pname=profile_name,
            )
        conn.commit()
        return None
    except oracledb.DatabaseError as e:
        logger.exception("DROP_PROFILE feilet for %s", profile_name)
        return str(e)


def _validate_object_list(conn: oracledb.Connection, object_list: list) -> Optional[str]:
    """Sjekker at hvert objekt i object_list faktisk eksisterer og eies av QUERYCHAT."""
    if not isinstance(object_list, list) or not object_list:
        return "object_list må være en ikke-tom liste"
    with conn.cursor() as cur:
        for obj in object_list:
            owner = (obj.get("owner") or "").upper()
            name = (obj.get("name") or "").upper()
            if owner != VALID_OBJECT_SCHEMA:
                return f"Objekter må eies av {VALID_OBJECT_SCHEMA} (fikk: {owner})"
            cur.execute(
                """
                SELECT COUNT(*) FROM all_objects
                WHERE owner = :owner AND object_name = :name
                AND object_type IN ('TABLE', 'VIEW')
                """,
                owner=owner, name=name,
            )
            if cur.fetchone()[0] == 0:
                return f"Objekt {owner}.{name} finnes ikke (eller er ikke tabell/view)"
    return None


# ── Admin: profil CRUD ────────────────────────────────────────────


def _list_profiles(conn: oracledb.Connection, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(f"SELECT {_PROFILE_SELECT_COLUMNS} FROM qc_ai_profiles ORDER BY display_name")
        profiles = [_row_to_profile(r) for r in cur.fetchall()]
    return _resp(ctx, {"ok": True, "profiles": profiles})


def _get_profile(conn: oracledb.Connection, profile_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(f"SELECT {_PROFILE_SELECT_COLUMNS} FROM qc_ai_profiles WHERE id = :id", id=profile_id)
        row = cur.fetchone()
    if not row:
        return _resp(ctx, {"ok": False, "error": "Profil ikke funnet"}, 404)
    return _resp(ctx, {"ok": True, "profile": _row_to_profile(row)})


def _list_queryable_objects(conn: oracledb.Connection, ctx) -> fdk.response.Response:
    """Hjelpe-endepunkt: hvilke tabeller/views i QUERYCHAT-skjemaet kan velges i object_list."""
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT object_name, object_type
            FROM all_objects
            WHERE owner = :owner
            AND object_type IN ('TABLE', 'VIEW')
            AND object_name NOT LIKE 'QC\\_%' ESCAPE '\\'
            ORDER BY object_type, object_name
            """,
            owner=VALID_OBJECT_SCHEMA,
        )
        objects = [{"owner": VALID_OBJECT_SCHEMA, "name": r[0], "type": r[1]} for r in cur.fetchall()]
    return _resp(ctx, {"ok": True, "objects": objects})


def _create_profile(conn: oracledb.Connection, body: dict, created_by: str, ctx) -> fdk.response.Response:
    profile_name = (body.get("profile_name") or "").strip().upper()
    display_name = (body.get("display_name") or "").strip()
    model        = (body.get("model") or "").strip()
    object_list  = body.get("object_list") or []

    if not profile_name or not display_name or not model:
        return _resp(ctx, {"ok": False, "error": "profile_name, display_name og model er påkrevd"}, 400)
    if not profile_name.replace("_", "").isalnum():
        return _resp(ctx, {"ok": False, "error": "profile_name kan kun inneholde bokstaver, tall og understrek"}, 400)

    val_err = _validate_object_list(conn, object_list)
    if val_err:
        return _resp(ctx, {"ok": False, "error": val_err}, 400)

    p = {
        "profile_name": profile_name,
        "display_name": display_name,
        "description":  body.get("description"),
        "provider":     body.get("provider", "oci"),
        "credential_name": body.get("credential_name", "OCI_GEN_AI_CRED"),
        "model": model,
        "oci_compartment_id": body.get("oci_compartment_id"),
        "region": body.get("region", "eu-frankfurt-2"),
        "max_tokens": int(body.get("max_tokens", 1024)),
        "temperature": float(body.get("temperature", 0)),
        "enable_sources": bool(body.get("enable_sources", True)),
        "annotations": bool(body.get("annotations", True)),
        "comments": bool(body.get("comments", True)),
        "case_sensitive_values": bool(body.get("case_sensitive_values", False)),
        "source_language": body.get("source_language", "no"),
        "target_language": body.get("target_language", "no"),
        "object_list": object_list,
    }

    new_id = None
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM qc_ai_profiles WHERE profile_name = :n", n=profile_name)
        if cur.fetchone()[0] > 0:
            return _resp(ctx, {"ok": False, "error": f"Profilnavn {profile_name} er allerede i bruk"}, 409)

        import secrets as _secrets
        new_id = _secrets.token_hex(16).upper()
        cur.execute(
            """
            INSERT INTO qc_ai_profiles (
                id, profile_name, display_name, description,
                provider, credential_name, model,
                oci_compartment_id, region,
                max_tokens, temperature,
                enable_sources, annotations, comments, case_sensitive_values,
                source_language, target_language, object_list,
                is_active, is_default, sync_status, created_by, updated_by
            ) VALUES (
                :id, :profile_name, :display_name, :description,
                :provider, :credential_name, :model,
                :oci_compartment_id, :region,
                :max_tokens, :temperature,
                :enable_sources, :annotations, :comments, :case_sensitive_values,
                :source_language, :target_language, :object_list,
                'Y', 'N', 'PENDING', :created_by, :created_by
            )
            """,
            id=new_id, profile_name=profile_name, display_name=display_name,
            description=p["description"],
            provider=p["provider"], credential_name=p["credential_name"], model=model,
            oci_compartment_id=p["oci_compartment_id"], region=p["region"],
            max_tokens=p["max_tokens"], temperature=p["temperature"],
            enable_sources=_bool_to_flag(p["enable_sources"]),
            annotations=_bool_to_flag(p["annotations"]),
            comments=_bool_to_flag(p["comments"]),
            case_sensitive_values=_bool_to_flag(p["case_sensitive_values"]),
            source_language=p["source_language"], target_language=p["target_language"],
            object_list=json.dumps(object_list),
            created_by=created_by,
        )
    conn.commit()

    sync_err = _sync_create_profile(conn, p)
    with conn.cursor() as cur:
        if sync_err:
            cur.execute(
                "UPDATE qc_ai_profiles SET sync_status = 'ERROR', sync_error = :err WHERE id = :id",
                err=sync_err[:2000], id=new_id,
            )
        else:
            cur.execute(
                "UPDATE qc_ai_profiles SET sync_status = 'SYNCED', sync_error = NULL WHERE id = :id",
                id=new_id,
            )
    conn.commit()

    logger.info("Opprettet AI-profil %s (sync: %s)", profile_name, "ERROR" if sync_err else "OK")
    return _resp(ctx, {
        "ok": True, "id": new_id, "profile_name": profile_name,
        "sync_status": "ERROR" if sync_err else "SYNCED",
        "sync_error": sync_err,
    }, 201)


def _update_profile(conn: oracledb.Connection, profile_id: str, body: dict, updated_by: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(f"SELECT {_PROFILE_SELECT_COLUMNS} FROM qc_ai_profiles WHERE id = :id", id=profile_id)
        row = cur.fetchone()
    if not row:
        return _resp(ctx, {"ok": False, "error": "Profil ikke funnet"}, 404)
    existing = _row_to_profile(row)

    object_list = body.get("object_list", existing["object_list"])
    val_err = _validate_object_list(conn, object_list)
    if val_err:
        return _resp(ctx, {"ok": False, "error": val_err}, 400)

    p = {
        "profile_name": existing["profile_name"],  # kan ikke endres
        "display_name": body.get("display_name", existing["display_name"]),
        "description":  body.get("description", existing["description"]),
        "provider":     body.get("provider", existing["provider"]),
        "credential_name": body.get("credential_name", existing["credential_name"]),
        "model": body.get("model", existing["model"]),
        "oci_compartment_id": body.get("oci_compartment_id", existing["oci_compartment_id"]),
        "region": body.get("region", existing["region"]),
        "max_tokens": int(body.get("max_tokens", existing["max_tokens"])),
        "temperature": float(body.get("temperature", existing["temperature"])),
        "enable_sources": bool(body.get("enable_sources", existing["enable_sources"])),
        "annotations": bool(body.get("annotations", existing["annotations"])),
        "comments": bool(body.get("comments", existing["comments"])),
        "case_sensitive_values": bool(body.get("case_sensitive_values", existing["case_sensitive_values"])),
        "source_language": body.get("source_language", existing["source_language"]),
        "target_language": body.get("target_language", "no"),
        "object_list": object_list,
    }
    is_active = bool(body.get("is_active", existing["is_active"]))

    with conn.cursor() as cur:
        cur.execute(
            """
            UPDATE qc_ai_profiles SET
                display_name = :display_name, description = :description,
                provider = :provider, credential_name = :credential_name, model = :model,
                oci_compartment_id = :oci_compartment_id, region = :region,
                max_tokens = :max_tokens, temperature = :temperature,
                enable_sources = :enable_sources, annotations = :annotations,
                comments = :comments, case_sensitive_values = :case_sensitive_values,
                source_language = :source_language, object_list = :object_list,
                is_active = :is_active, sync_status = 'PENDING',
                updated_by = :updated_by, updated_at = SYSTIMESTAMP
            WHERE id = :id
            """,
            display_name=p["display_name"], description=p["description"],
            provider=p["provider"], credential_name=p["credential_name"], model=p["model"],
            oci_compartment_id=p["oci_compartment_id"], region=p["region"],
            max_tokens=p["max_tokens"], temperature=p["temperature"],
            enable_sources=_bool_to_flag(p["enable_sources"]),
            annotations=_bool_to_flag(p["annotations"]),
            comments=_bool_to_flag(p["comments"]),
            case_sensitive_values=_bool_to_flag(p["case_sensitive_values"]),
            source_language=p["source_language"], object_list=json.dumps(object_list),
            is_active=_bool_to_flag(is_active),
            updated_by=updated_by, id=profile_id,
        )
    conn.commit()

    sync_err = None
    if is_active:
        sync_err = _sync_update_profile(conn, p)

    with conn.cursor() as cur:
        if sync_err:
            cur.execute(
                "UPDATE qc_ai_profiles SET sync_status = 'ERROR', sync_error = :err WHERE id = :id",
                err=sync_err[:2000], id=profile_id,
            )
        else:
            cur.execute(
                "UPDATE qc_ai_profiles SET sync_status = 'SYNCED', sync_error = NULL WHERE id = :id",
                id=profile_id,
            )
    conn.commit()

    logger.info("Oppdatert AI-profil %s (sync: %s)", p["profile_name"], "ERROR" if sync_err else "OK")
    return _resp(ctx, {
        "ok": True, "id": profile_id,
        "sync_status": "ERROR" if sync_err else "SYNCED",
        "sync_error": sync_err,
    })


def _delete_profile(conn: oracledb.Connection, profile_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute("SELECT profile_name, is_default FROM qc_ai_profiles WHERE id = :id", id=profile_id)
        row = cur.fetchone()
    if not row:
        return _resp(ctx, {"ok": False, "error": "Profil ikke funnet"}, 404)
    profile_name, is_default = row
    if is_default == "Y":
        return _resp(ctx, {"ok": False, "error": "Kan ikke slette standardprofilen. Sett en annen profil som standard først."}, 400)

    sync_err = _sync_drop_profile(conn, profile_name)
    # Slett uansett fra katalogen selv om ADB-droppet feilet (f.eks. fordi
    # profilen aldri ble synket) - men rapporter advarselen til admin
    with conn.cursor() as cur:
        cur.execute("DELETE FROM qc_ai_profiles WHERE id = :id", id=profile_id)
    conn.commit()

    logger.info("Slettet AI-profil %s", profile_name)
    return _resp(ctx, {"ok": True, "deleted": profile_id, "drop_warning": sync_err})


def _set_default_profile(conn: oracledb.Connection, profile_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM qc_ai_profiles WHERE id = :id AND is_active = 'Y'", id=profile_id)
        if cur.fetchone()[0] == 0:
            return _resp(ctx, {"ok": False, "error": "Profil ikke funnet eller ikke aktiv"}, 404)
        cur.execute("UPDATE qc_ai_profiles SET is_default = 'N' WHERE is_default = 'Y'")
        cur.execute("UPDATE qc_ai_profiles SET is_default = 'Y' WHERE id = :id", id=profile_id)
    conn.commit()
    return _resp(ctx, {"ok": True, "default_profile_id": profile_id})


# ── Admin: brukertilgang ──────────────────────────────────────────


def _list_profile_access(conn: oracledb.Connection, profile_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT u.id, u.email, u.display_name,
                   CASE WHEN up.user_id IS NOT NULL THEN 1 ELSE 0 END AS has_access
            FROM   qc_users u
            LEFT   JOIN qc_user_ai_profiles up
                   ON up.user_id = u.id AND up.ai_profile_id = :profile_id
            ORDER  BY u.display_name
            """,
            profile_id=profile_id,
        )
        users = [
            {"id": r[0], "email": r[1], "display_name": r[2], "has_access": bool(r[3])}
            for r in cur.fetchall()
        ]
    return _resp(ctx, {"ok": True, "users": users})


def _grant_access(conn: oracledb.Connection, profile_id: str, user_id: str, granted_by: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM qc_ai_profiles WHERE id = :id", id=profile_id)
        if cur.fetchone()[0] == 0:
            return _resp(ctx, {"ok": False, "error": "Profil ikke funnet"}, 404)
        try:
            cur.execute(
                """
                INSERT INTO qc_user_ai_profiles (user_id, ai_profile_id, granted_by)
                VALUES (:p_uid, :pid, :gby)
                """,
                p_uid=user_id, pid=profile_id, gby=granted_by,
            )
        except oracledb.IntegrityError:
            return _resp(ctx, {"ok": True, "already_granted": True})
    conn.commit()
    return _resp(ctx, {"ok": True})


def _revoke_access(conn: oracledb.Connection, profile_id: str, user_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            "DELETE FROM qc_user_ai_profiles WHERE user_id = :p_uid AND ai_profile_id = :pid",
            p_uid=user_id, pid=profile_id,
        )
        # Hvis dette var brukerens aktive profil, fall tilbake til default
        cur.execute(
            "SELECT ai_profile_id FROM qc_user_active_ai_profile WHERE user_id = :p_uid",
            p_uid=user_id,
        )
        active_row = cur.fetchone()
        if active_row and active_row[0] == profile_id:
            cur.execute("SELECT id FROM qc_ai_profiles WHERE is_default = 'Y'")
            default_row = cur.fetchone()
            if default_row:
                cur.execute(
                    """
                    UPDATE qc_user_active_ai_profile
                    SET ai_profile_id = :pid, updated_at = SYSTIMESTAMP
                    WHERE user_id = :p_uid
                    """,
                    pid=default_row[0], p_uid=user_id,
                )
    conn.commit()
    return _resp(ctx, {"ok": True})


# ── Bruker: eget profilvalg ────────────────────────────────────────


def _list_my_profiles(conn: oracledb.Connection, user_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            f"""
            SELECT {_PROFILE_SELECT_COLUMNS}
            FROM   qc_ai_profiles p
            JOIN   qc_user_ai_profiles up ON up.ai_profile_id = p.id
            WHERE  up.user_id = :p_uid AND p.is_active = 'Y'
            ORDER  BY p.display_name
            """,
            p_uid=user_id,
        )
        profiles = [_row_to_profile(r) for r in cur.fetchall()]

        cur.execute(
            "SELECT ai_profile_id FROM qc_user_active_ai_profile WHERE user_id = :p_uid",
            p_uid=user_id,
        )
        active_row = cur.fetchone()
        active_id = active_row[0] if active_row else None

    return _resp(ctx, {"ok": True, "profiles": profiles, "active_profile_id": active_id})


def _get_my_active_profile(conn: oracledb.Connection, user_id: str, ctx) -> fdk.response.Response:
    with conn.cursor() as cur:
        cur.execute(
            f"""
            SELECT {_PROFILE_SELECT_COLUMNS}
            FROM   qc_ai_profiles p
            JOIN   qc_user_active_ai_profile a ON a.ai_profile_id = p.id
            WHERE  a.user_id = :p_uid
            """,
            p_uid=user_id,
        )
        row = cur.fetchone()
        if not row:
            # Fall tilbake til systemets default
            cur.execute(f"SELECT {_PROFILE_SELECT_COLUMNS} FROM qc_ai_profiles WHERE is_default = 'Y'")
            row = cur.fetchone()
    if not row:
        return _resp(ctx, {"ok": False, "error": "Ingen AI-profil tilgjengelig"}, 404)
    return _resp(ctx, {"ok": True, "profile": _row_to_profile(row)})


def _set_my_active_profile(conn: oracledb.Connection, user_id: str, body: dict, ctx) -> fdk.response.Response:
    profile_id = body.get("profile_id")
    if not profile_id:
        return _resp(ctx, {"ok": False, "error": "profile_id er påkrevd"}, 400)

    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT COUNT(*) FROM qc_user_ai_profiles
            WHERE user_id = :p_uid AND ai_profile_id = :pid
            """,
            p_uid=user_id, pid=profile_id,
        )
        if cur.fetchone()[0] == 0:
            return _resp(ctx, {"ok": False, "error": "Du har ikke tilgang til denne profilen"}, 403)

        cur.execute(
            """
            MERGE INTO qc_user_active_ai_profile t
            USING (SELECT :p_uid AS user_id FROM dual) s
            ON (t.user_id = s.user_id)
            WHEN MATCHED THEN
                UPDATE SET ai_profile_id = :pid, updated_at = SYSTIMESTAMP
            WHEN NOT MATCHED THEN
                INSERT (user_id, ai_profile_id) VALUES (:p_uid, :pid)
            """,
            p_uid=user_id, pid=profile_id,
        )
    conn.commit()
    return _resp(ctx, {"ok": True, "active_profile_id": profile_id})


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

            # ── /me/ai-profiles  |  /me/ai-profile ──────────────────
            if len(path) >= 1 and path[0] == "me":
                if len(path) == 2 and path[1] == "ai-profiles" and method == "GET":
                    return _list_my_profiles(conn, user_id, ctx)
                if len(path) == 2 and path[1] == "ai-profile":
                    if method == "GET":
                        return _get_my_active_profile(conn, user_id, ctx)
                    if method == "PUT":
                        return _set_my_active_profile(conn, user_id, body, ctx)
                return _resp(ctx, {"ok": False, "error": "Ukjent endepunkt"}, 404)

            # ── /admin/ai-profiles/* ─────────────────────────────────
            if len(path) >= 2 and path[0] == "admin" and path[1] == "ai-profiles":
                _require_permission(payload, "admin:aiprofiles")
                sub = path[2:]

                if len(sub) == 0:
                    if method == "GET":
                        return _list_profiles(conn, ctx)
                    if method == "POST":
                        return _create_profile(conn, body, user_id, ctx)

                elif len(sub) == 1 and sub[0] == "objects":
                    if method == "GET":
                        return _list_queryable_objects(conn, ctx)

                elif len(sub) == 1:
                    profile_id = sub[0]
                    if method == "GET":
                        return _get_profile(conn, profile_id, ctx)
                    if method == "PUT":
                        return _update_profile(conn, profile_id, body, user_id, ctx)
                    if method == "DELETE":
                        return _delete_profile(conn, profile_id, ctx)

                elif len(sub) == 2 and sub[1] == "default":
                    profile_id = sub[0]
                    if method == "PUT":
                        return _set_default_profile(conn, profile_id, ctx)

                elif len(sub) == 2 and sub[1] == "access":
                    profile_id = sub[0]
                    if method == "GET":
                        return _list_profile_access(conn, profile_id, ctx)

                elif len(sub) == 3 and sub[1] == "access":
                    profile_id, target_user_id = sub[0], sub[2]
                    if method == "PUT":
                        return _grant_access(conn, profile_id, target_user_id, user_id, ctx)
                    if method == "DELETE":
                        return _revoke_access(conn, profile_id, target_user_id, ctx)

                return _resp(ctx, {"ok": False, "error": "Ukjent endepunkt"}, 404)

    except PermissionError as e:
        return _resp(ctx, {"ok": False, "error": str(e)}, 403)
    except oracledb.DatabaseError as e:
        logger.exception("Database-feil")
        return _resp(ctx, {"ok": False, "error": "Databasefeil", "detail": str(e)}, 500)
    except Exception as e:
        logger.exception("Uventet feil")
        return _resp(ctx, {"ok": False, "error": str(e), "type": type(e).__name__}, 500)

    return _resp(ctx, {"ok": False, "error": "Ukjent endepunkt"}, 404)
