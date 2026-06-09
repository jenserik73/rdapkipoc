"""
OCI Function: feedback-executor

Tar imot tilbakemeldinger fra QueryChat-frontend og oppdaterer
rad i ADB via querychat.querychat_pkg.save_feedback(p_id).

Forventet body:
  {
    "logId":        152,
    "vote":         1,            # 1 = positiv, -1 = negativ
    "feedbackText": "Bra svar!",  # valgfri fritekst
    "correctedSql": "SELECT ..."  # valgfri korrigert SQL
  }
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

_pool           = None
_secrets_client = None
_wallet_dir     = "/tmp/wallet"


def _get_secrets_client() -> oci.secrets.SecretsClient:
    global _secrets_client
    if _secrets_client is None:
        signer = oci.auth.signers.get_resource_principals_signer()
        _secrets_client = oci.secrets.SecretsClient({}, signer=signer)
    return _secrets_client


def _get_secret(ocid: str) -> bytes:
    bundle = _get_secrets_client().get_secret_bundle(secret_id=ocid).data
    return base64.b64decode(bundle.secret_bundle_content.content)


def _init_pool() -> oracledb.ConnectionPool:
    logger.info("Henter secrets fra Vault …")
    db_password     = _get_secret(DBPASS_SECRET_OCID).decode().strip()
    wallet_password = _get_secret(WALLETPASS_SECRET_OCID).decode().strip()
    wallet_zip      = _get_secret(WALLET_SECRET_OCID)

    os.makedirs(_wallet_dir, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(wallet_zip)) as zf:
        zf.extractall(_wallet_dir)

    pool = oracledb.create_pool(
        user=DB_USER,
        password=db_password,
        dsn=DB_DSN,
        min=1, max=3, increment=1,
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


def _save_feedback(log_id: int, vote: int,
                   feedback_text: str = None,
                   corrected_sql: str = None):
    pool = _get_pool()
    with pool.acquire() as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                BEGIN
                  querychat.querychat_pkg.save_feedback(
                    p_id            => :log_id,
                    p_vote          => :vote,
                    p_feedback_text => :feedback_text,
                    p_corrected_sql => :corrected_sql
                  );
                END;
                """,
                log_id=log_id,
                vote=vote,
                feedback_text=feedback_text,
                corrected_sql=corrected_sql,
            )
        conn.commit()
    logger.info("Tilbakemelding lagret: logId=%d vote=%d", log_id, vote)


def handler(ctx, data: io.BytesIO = None):
    try:
        body = json.loads(data.getvalue())
    except Exception:
        return _resp(ctx, {"ok": False, "error": "Ugyldig JSON"}, 400)

    log_id        = body.get("logId")
    feedback_text = body.get("feedbackText")
    corrected_sql = body.get("correctedSql")

    if log_id is None:
        return _resp(ctx, {"ok": False, "error": "Mangler 'logId'-felt"}, 400)

    try:
        vote = int(body.get("vote", 0))
    except (TypeError, ValueError):
        return _resp(ctx, {"ok": False, "error": "vote må være et heltall (1 eller -1)"}, 400)

    if vote not in (1, -1):
        return _resp(ctx, {"ok": False, "error": "vote må være 1 (positiv) eller -1 (negativ)"}, 400)

    try:
        _save_feedback(
            log_id=int(log_id),
            vote=vote,
            feedback_text=feedback_text,
            corrected_sql=corrected_sql,
        )
        return _resp(ctx, {"ok": True})
    except Exception as e:
        logger.exception("Feil ved lagring av tilbakemelding")
        return _resp(ctx, {"ok": False, "error": str(e)}, 500)


def _resp(ctx, data: dict, status: int = 200) -> fdk.response.Response:
    return fdk.response.Response(
        ctx,
        response_data=json.dumps(data, ensure_ascii=False),
        headers={"Content-Type": "application/json; charset=utf-8"},
        status_code=status,
    )