"""
OCI Function: sql-executor  (v2 — DBMS_CLOUD_AI)

Kraftig forenklet: Funksjonen er nå et tynt lag mellom
API Gateway og ADB-pakken QUERYCHAT_PKG.

Flyten:
  1. Ta imot norsk spørsmål fra frontend
  2. Kall myschema.querychat_pkg.ask_nl() i ADB
     → ADB gjør NL2SQL via DBMS_CLOUD_AI (intern OCI LLM)
     → ADB kjører SQL og returnerer JSON
  3. Returner JSON direkte til frontend

Ingen data forlater OCI. Ingen ekstern LLM-API kalles.
"""

import io
import json
import logging
import os
import zipfile
import base64

import fdk.response
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
AI_PROFILE             = _require_env("AI_PROFILE")
MAX_ROWS               = _require_env("MAX_ROWS")
WALLET_SECRET_OCID     = _require_env("WALLET_SECRET_OCID")
DBPASS_SECRET_OCID     = _require_env("DBPASS_SECRET_OCID")
WALLETPASS_SECRET_OCID = _require_env("WALLETPASS_SECRET_OCID")

_pool           = None
_secrets_client = None
_wallet_dir     = "/tmp/wallet"


# ── hent secret fra Vault via Resource Principal ───────────────

def _get_secrets_client() -> oci.secrets.SecretsClient:
    """Lager SecretsClient én gang og gjenbruker den (per container)."""
    global _secrets_client
    if _secrets_client is None:
        signer = oci.auth.signers.get_resource_principals_signer()
        _secrets_client = oci.secrets.SecretsClient({}, signer=signer)
    return _secrets_client


def _get_secret(ocid: str) -> bytes:
    """Henter og base64-dekoder et secret fra OCI Vault."""
    bundle = _get_secrets_client().get_secret_bundle(secret_id=ocid).data
    return base64.b64decode(bundle.secret_bundle_content.content)


# ── connection pool (initialiseres én gang per container) ──────

def _init_pool() -> oracledb.ConnectionPool:
    logger.info("Henter secrets fra Vault …")

    db_password     = _get_secret(DBPASS_SECRET_OCID).decode().strip()
    wallet_password = _get_secret(WALLETPASS_SECRET_OCID).decode().strip()
    wallet_zip      = _get_secret(WALLET_SECRET_OCID)

    logger.info("DB-passord lengde: %d", len(db_password))
    logger.info("Wallet-passord lengde: %d", len(wallet_password))
    logger.info("Wallet zip størrelse: %d bytes", len(wallet_zip))

    os.makedirs(_wallet_dir, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(wallet_zip)) as zf:
        zf.extractall(_wallet_dir)

    logger.info("Wallet filer: %s", os.listdir(_wallet_dir))
    logger.info("DSN: %s", DB_DSN)

    tns_path = os.path.join(_wallet_dir, "tnsnames.ora")
    with open(tns_path, "r", encoding="utf-8") as f:
        logger.info("tnsnames.ora:\n%s", f.read())

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


# ── kall ADB-pakken ────────────────────────────────────────────

def _ask_nl(question: str) -> dict:
    """
    Kaller querychat.querychat_pkg.ask_nl() i ADB.
    Returnerer JSON-respons fra pakken som Python-dict.
    """
    pool = _get_pool()
    logger.info("Henter tilkobling fra pool …")
    with pool.acquire() as conn:
        with conn.cursor() as cur:
            logger.info("Kaller PL/SQL-funksjonen …")
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
                profile=AI_PROFILE,
                max_rows=MAX_ROWS,
            )
            clob_val = result_clob.getvalue()
            # Les CLOB én gang og gjenbruk verdien
            clob_content = clob_val.read(1, clob_val.size()) if clob_val else None
            logger.info("CLOB innhold: %s", clob_content)
            return json.loads(clob_content or '{"ok":false,"error":"Tom respons"}')


def _save_feedback(question: str, sql: str, vote: int, corrected: str = None):
    """Lagrer brukertilbakemelding i ADB-loggtabellen."""
    pool = _get_pool()
    with pool.acquire() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                BEGIN
                  querychat.querychat_pkg.save_feedback(
                    p_question  => :question,
                    p_sql       => :sql,
                    p_vote      => :vote,
                    p_corrected => :corrected
                  );
                END;
                """,
                question=question,
                sql=sql,
                vote=vote,
                corrected=corrected,
            )


# ── Function handler ───────────────────────────────────────────

def handler(ctx, data: io.BytesIO = None):
    """
    POST /v1/ask
      Body: {"question": "Vis topp 5 kunder"}
      → Returnerer JSON med kolonner, rader og den genererte SQL-en

    POST /v1/feedback
      Body: {"question":"...", "sql":"...", "vote":1, "corrected":"SELECT ..."}
      → Lagrer tilbakemelding i ADB
    """
    try:
        body = json.loads(data.getvalue())
    except Exception:
        return _resp(ctx, {"ok": False, "error": "Ugyldig JSON"}, 400)

    action = body.get("action", "ask")

    if action == "feedback":
        try:
            _save_feedback(
                question=body.get("question", ""),
                sql=body.get("sql", ""),
                vote=int(body.get("vote", 0)),
                corrected=body.get("corrected"),
            )
            return _resp(ctx, {"ok": True})
        except Exception as e:
            logger.exception("Feil ved lagring av tilbakemelding")
            return _resp(ctx, {"ok": False, "error": str(e)}, 500)

    # Standard: spør ADB
    question = body.get("question", "").strip()
    if not question:
        return _resp(ctx, {"ok": False, "error": "Mangler 'question'-felt"}, 400)

    logger.info("Spørsmål: %s", question)
    try:
        result = _ask_nl(question)
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