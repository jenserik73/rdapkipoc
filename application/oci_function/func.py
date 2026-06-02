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
import tempfile
import zipfile
import base64

import fdk.response
import oci
import oracledb

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# ── konfigurasjon ──────────────────────────────────────────────
DB_USER            = "rdap_chatbot_app_user"
DB_DSN             = "rdapkipocdb_high"
WALLET_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
DBPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
AI_PROFILE         = "QUERYCHAT_PROFILE"
MAX_ROWS           = "500"

_pool = None
_wallet_dir = None


# ── hent secret fra Vault via Instance Principal ───────────────

def _get_secret(ocid: str) -> bytes:
    signer = oci.auth.signers.get_resource_principals_signer()
    client = oci.secrets.SecretsClient({}, signer=signer)
    bundle = client.get_secret_bundle(secret_id=ocid).data
    return base64.b64decode(bundle.secret_bundle_content.content)


# ── connection pool (initialiseres én gang per container) ──────

def _init_pool():
    global _wallet_dir
    logger.info("Henter wallet …")
    db_password = _get_secret(DBPASS_SECRET_OCID).decode().strip()
    wallet_zip = _get_secret(WALLET_SECRET_OCID)
  

    _wallet_dir = tempfile.mkdtemp(prefix="wallet_")
    with zipfile.ZipFile(io.BytesIO(wallet_zip)) as zf:
        zf.extractall(_wallet_dir)

    filnavn = "tnsnames.ora"
    filsti = os.path.join(_wallet_dir, filnavn)

    with open(filsti, "r", encoding="utf-8") as f:
        innhold = f.read()
        logger.info(innhold)  

    pool = oracledb.create_pool(
        user=DB_USER,
        password=db_password,
        dsn=DB_DSN,
        min=1, max=5, increment=1,
        config_dir=_wallet_dir,
        wallet_location=_wallet_dir,
        wallet_password=db_password
    )
    logger.info("Pool klar")
    return pool


def _get_pool():
    global _pool
    if _pool is None:
        _pool = _init_pool()
    return _pool


# ── kall ADB-pakken ────────────────────────────────────────────

def _ask_nl(question: str) -> dict:
    """
    Kaller myschema.querychat_pkg.ask_nl() i ADB.
    Returnerer JSON-respons fra pakken som Python-dict.
    """
    pool = _get_pool()
    logger.info("Pool aquire")
    with pool.acquire() as conn:
        logger.info("open cursor")
        with conn.cursor() as cur:
            # Kall PL/SQL-funksjonen og hent CLOB-resultatet
            logger.info("Kall PL/SQL-funksjonen og hent CLOB-resultatet")
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
            logger.info("end get _ask_nl")
            logger.info(clob_val.read(1,clob_val.size()))
            return json.loads(clob_val.read(1,clob_val.size()) if clob_val else '{"ok":false,"error":"Tom respons"}')


def _save_feedback(question: str, sql: str, vote: int, corrected: str = None):
    """Lagrer brukertilbakemelding i ADB-loggtabellen."""
    pool = _get_pool()
    with pool.acquire() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                BEGIN
                  myschema.querychat_pkg.save_feedback(
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

    # Rute basert på action-felt (API Gateway kan også rute på path)
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
        logger.info("ask_nl result")
        return _resp(ctx, result)
    except Exception as e:
        logger.exception("Feil i ask_nl")
        return _resp(ctx, {"ok": False, "error": str(e), "code": "UNKNOWN"}, 500)


def _resp(ctx, data: dict, status: int = 200):
    return fdk.response.Response(
        ctx,
        response_data=json.dumps(data, ensure_ascii=False),
        headers={"Content-Type": "application/json; charset=utf-8"},
        status_code=status,
    )