"""
OCI Function: sql-executor  (v3 — dynamisk AI-profil per bruker)

Funksjonen er et tynt lag mellom API Gateway og ADB-pakken QUERYCHAT_PKG.

Flyten:
  1. Ta imot norsk spørsmål fra frontend
  2. Valider JWT fra Authorization-header
  3. Slå opp brukerens AKTIVE AI-profil (qc_user_active_ai_profile) og
     verifiser at brukeren faktisk har tilgang til den
     (fallback til AI_PROFILE-miljøvariabelen hvis ingen er valgt)
  4. Kall querychat.querychat_pkg.ask_nl() i ADB med riktig profilnavn
     → ADB gjør NL2SQL via DBMS_CLOUD_AI (intern OCI LLM)
     → ADB kjører SQL og returnerer JSON
  5. Returner JSON direkte til frontend

Ingen data forlater OCI. Ingen ekstern LLM-API kalles.
Sett LOG_LEVEL=DEBUG i miljøvariabler for detaljert logging.
"""

import io
import json
import logging
import os
import zipfile
import base64

import fdk.response
import jwt
import oci
import oracledb

LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
logging.basicConfig(level=getattr(logging, LOG_LEVEL, logging.INFO))
logger = logging.getLogger(__name__)
FUNC_VERSION = os.getenv("FUNC_VERSION", "dev-ukjent")

# ── konfigurasjon ──────────────────────────────────────────────
def _require_env(name: str) -> str:
    val = os.getenv(name)
    if not val:
        raise EnvironmentError(f"Mangler påkrevd miljøvariabel: {name}")
    return val

DB_USER                = _require_env("DB_USER")
DB_DSN                 = _require_env("DB_DSN")
AI_PROFILE             = _require_env("AI_PROFILE")  # fallback dersom bruker ikke har valgt profil
MAX_ROWS               = _require_env("MAX_ROWS")
WALLET_SECRET_OCID     = _require_env("WALLET_SECRET_OCID")
DBPASS_SECRET_OCID     = _require_env("DBPASS_SECRET_OCID")
WALLETPASS_SECRET_OCID = _require_env("WALLETPASS_SECRET_OCID")
JWT_SECRET_OCID        = _require_env("JWT_SECRET_OCID")

_pool           = None
_secrets_client = None
_wallet_dir     = "/tmp/wallet"
_jwt_secret     = None


# ── hent secret fra Vault via Resource Principal ───────────────

def _get_secrets_client() -> oci.secrets.SecretsClient:
    global _secrets_client
    if _secrets_client is None:
        signer = oci.auth.signers.get_resource_principals_signer()
        _secrets_client = oci.secrets.SecretsClient({}, signer=signer)
    return _secrets_client


def _get_secret(ocid: str) -> bytes:
    bundle = _get_secrets_client().get_secret_bundle(secret_id=ocid).data
    return base64.b64decode(bundle.secret_bundle_content.content)


# ── JWT-validering ─────────────────────────────────────────────

def _get_jwt_secret() -> str:
    global _jwt_secret
    if _jwt_secret is None:
        _jwt_secret = _get_secret(JWT_SECRET_OCID).decode().strip()
    return _jwt_secret


def _verify_jwt(ctx) -> dict:
    headers = dict(ctx.Headers())
    auth_header = headers.get("authorization", headers.get("Authorization", ""))
    if not auth_header.startswith("Bearer "):
        raise PermissionError("Mangler Authorization-header")
    token = auth_header.removeprefix("Bearer ").strip()
    return jwt.decode(token, _get_jwt_secret(), algorithms=["HS256"])


# ── connection pool ────────────────────────────────────────────

def _init_pool() -> oracledb.ConnectionPool:
    logger.info("Initialiserer connection pool")

    db_password     = _get_secret(DBPASS_SECRET_OCID).decode().strip()
    wallet_password = _get_secret(WALLETPASS_SECRET_OCID).decode().strip()
    wallet_zip      = _get_secret(WALLET_SECRET_OCID)

    logger.debug("DB-passord lengde: %d", len(db_password))
    logger.debug("Wallet-passord lengde: %d", len(wallet_password))
    logger.debug("Wallet zip størrelse: %d bytes", len(wallet_zip))

    os.makedirs(_wallet_dir, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(wallet_zip)) as zf:
        zf.extractall(_wallet_dir)

    logger.debug("Wallet filer: %s", os.listdir(_wallet_dir))
    logger.debug("DSN: %s", DB_DSN)

    tns_path = os.path.join(_wallet_dir, "tnsnames.ora")
    with open(tns_path, "r", encoding="utf-8") as f:
        logger.debug("tnsnames.ora:\n%s", f.read())

    pool = oracledb.create_pool(
        user=DB_USER,
        password=db_password,
        dsn=DB_DSN,
        min=1, max=5, increment=1,
        config_dir=_wallet_dir,
        wallet_location=_wallet_dir,
        wallet_password=wallet_password,
    )
    logger.info("Connection pool klar")
    return pool


def _get_pool() -> oracledb.ConnectionPool:
    global _pool
    if _pool is None:
        _pool = _init_pool()
    return _pool


# ── AI-profil-oppslag ───────────────────────────────────────────

def _resolve_ai_profile(conn: oracledb.Connection, user_id: str) -> str:
    """
    Finner profile_name som skal brukes for denne brukeren:
      1. Brukerens valgte aktive profil (qc_user_active_ai_profile),
         MEN kun hvis brukeren fortsatt har tilgang (qc_user_ai_profiles)
         og profilen er aktiv og synket.
      2. Ellers: systemets standardprofil (is_default = 'Y').
      3. Ellers: AI_PROFILE-miljøvariabelen (bakoverkompatibilitet).
    """
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT p.profile_name
            FROM   querychat.qc_ai_profiles p
            JOIN   querychat.qc_user_active_ai_profile a ON a.ai_profile_id = p.id
            JOIN   querychat.qc_user_ai_profiles up
                   ON up.ai_profile_id = p.id AND up.user_id = a.user_id
            WHERE  a.user_id = :p_uid
            AND    p.is_active = 'Y'
            AND    p.sync_status = 'SYNCED'
            """,
            p_uid=user_id,
        )
        row = cur.fetchone()
        if row:
            return row[0]

        cur.execute(
            """
            SELECT profile_name FROM querychat.qc_ai_profiles
            WHERE is_default = 'Y' AND is_active = 'Y' AND sync_status = 'SYNCED'
            """
        )
        row = cur.fetchone()
        if row:
            return row[0]

    logger.warning("Ingen AI-profil funnet i katalogen for bruker %s - bruker AI_PROFILE-fallback", user_id)
    return AI_PROFILE


# ── kall ADB-pakken ────────────────────────────────────────────

def _ask_nl(question: str, user_id: str) -> dict:
    pool = _get_pool()
    logger.debug("Henter tilkobling fra pool")
    with pool.acquire() as conn:
        profile_name = _resolve_ai_profile(conn, user_id)
        logger.debug("Bruker AI-profil: %s", profile_name)

        with conn.cursor() as cur:
            logger.debug("Kaller PL/SQL-funksjonen")
            result_clob = cur.var(oracledb.DB_TYPE_CLOB)
            cur.execute(
                """
                BEGIN
                  :result := querychat.querychat_pkg.ask_nl(
                    p_question => :question,
                    p_profile  => :profile,
                    p_max_rows => :max_rows
                  );
                END;
                """,
                result=result_clob,
                question=question,
                profile=profile_name,
                max_rows=MAX_ROWS,
            )
            clob_val = result_clob.getvalue()
            clob_content = clob_val.read() if clob_val else None
            logger.debug("CLOB innhold: %s", clob_content)
            try:
                parsed = json.loads(clob_content or '{"ok":false,"error":"Tom respons"}')
            except Exception:
                parsed = {"ok": False, "error": clob_content or "Tom respons fra ADB"}
            parsed["aiProfile"] = profile_name
            return parsed

# ── Function handler ───────────────────────────────────────────

def handler(ctx, data: io.BytesIO = None):
    try:
        jwt_payload = _verify_jwt(ctx)
    except PermissionError as e:
        return _resp(ctx, {"ok": False, "error": str(e)}, 401)
    except Exception as e:
        logger.warning("JWT-validering feilet: %s", str(e))
        return _resp(ctx, {"ok": False, "error": "Ugyldig eller utløpt token"}, 401)

    user_id = jwt_payload.get("sub")

    try:
        body = json.loads(data.getvalue())
    except Exception:
        return _resp(ctx, {"ok": False, "error": "Ugyldig JSON"}, 400)

    question = body.get("question", "").strip()
    if not question:
        return _resp(ctx, {"ok": False, "error": "Mangler 'question'-felt"}, 400)

    logger.info("[%s] Spørsmål fra bruker %s: %s", FUNC_VERSION, jwt_payload.get("email", "ukjent"), question)
    try:
        result = _ask_nl(question, user_id)
        logger.info("ask_nl fullført")
        return _resp(ctx, result)
    except Exception as e:
        logger.exception("Feil i ask_nl")
        return _resp(ctx, {"ok": False, "error": str(e), "code": "UNKNOWN"}, 500)


def _resp(ctx, data: dict, status: int = 200) -> fdk.response.Response:
    return fdk.response.Response(
        ctx,
        response_data=json.dumps(data, ensure_ascii=False),
        headers={"Content-Type": "application/json; charset=utf-8"},
        status_code=status,
    )
