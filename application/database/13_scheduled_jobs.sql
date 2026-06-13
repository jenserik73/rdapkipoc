-- ============================================================
-- QueryChat – Schedulerte jobber
-- Kjøres én gang som querychat-bruker i ADB
-- ============================================================

-- ── Rydd opp utløpte og revokerte refresh tokens ───────────
BEGIN
  -- Slett eksisterende jobb hvis den finnes
  BEGIN
    DBMS_SCHEDULER.DROP_JOB('cleanup_tokens', force => TRUE);
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'cleanup_tokens',
    job_type        => 'PLSQL_BLOCK',
    job_action      => '
      BEGIN
        DELETE FROM qc_refresh_tokens
        WHERE revoked = 1
           OR expires_at < SYSTIMESTAMP - INTERVAL ''7'' DAY;
        COMMIT;
      END;
    ',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY;BYHOUR=3;BYMINUTE=0',
    enabled         => TRUE,
    comments        => 'Rydder opp utløpte og revokerte refresh tokens daglig kl. 03:00'
  );
END;
/

-- ── Rydd opp brukte og utløpte passord-reset tokens ────────
BEGIN
  BEGIN
    DBMS_SCHEDULER.DROP_JOB('cleanup_password_resets', force => TRUE);
  EXCEPTION
    WHEN OTHERS THEN NULL;
  END;

  DBMS_SCHEDULER.CREATE_JOB(
    job_name        => 'cleanup_password_resets',
    job_type        => 'PLSQL_BLOCK',
    job_action      => '
      BEGIN
        DELETE FROM qc_password_resets
        WHERE used = 1
           OR expires_at < SYSTIMESTAMP - INTERVAL ''1'' DAY;
        COMMIT;
      END;
    ',
    start_date      => SYSTIMESTAMP,
    repeat_interval => 'FREQ=DAILY;BYHOUR=3;BYMINUTE=5',
    enabled         => TRUE,
    comments        => 'Rydder opp brukte og utløpte passord-reset tokens daglig kl. 03:05'
  );
END;
/

-- ── Verifiser at jobbene er opprettet ──────────────────────
SELECT job_name, enabled, state, repeat_interval, last_start_date, next_run_date
FROM user_scheduler_jobs
WHERE job_name IN ('CLEANUP_TOKENS', 'CLEANUP_PASSWORD_RESETS')
ORDER BY job_name;