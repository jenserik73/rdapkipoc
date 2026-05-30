-- =============================================================
-- 04_feedback_table.sql
-- Logg-tabell for few-shot læring — skjema querychat
-- =============================================================

CREATE TABLE querychat.querychat_feedback (
  id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  question      VARCHAR2(2000)  NOT NULL,
  generated_sql VARCHAR2(32767) NOT NULL,
  correct_sql   VARCHAR2(32767),
  vote          NUMBER(2) DEFAULT 0,   -- 1=bra, -1=dårlig, 0=ikke vurdert
  created_at    TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at    TIMESTAMP
);

COMMENT ON TABLE querychat.querychat_feedback IS
  'Few-shot læringslogg for QueryChat. Godkjente spørringer (vote=1)
   injiseres automatisk i prompten til DBMS_CLOUD_AI.';

CREATE INDEX querychat.qcf_vote_idx
  ON querychat.querychat_feedback(vote, created_at DESC);

CREATE OR REPLACE VIEW querychat.querychat_few_shot AS
  SELECT question,
         NVL(correct_sql, generated_sql) AS correct_sql,
         vote,
         created_at
  FROM   querychat.querychat_feedback
  WHERE  vote > 0
  ORDER  BY vote DESC, created_at DESC;

-- Gi app-brukeren tilgang
GRANT EXECUTE    ON querychat.querychat_pkg      TO querychat;
GRANT SELECT, INSERT, UPDATE
                 ON querychat.querychat_feedback  TO querychat;
GRANT SELECT     ON querychat.querychat_few_shot  TO querychat;

-- SELECT på datatabellene
GRANT SELECT ON querychat.ki_grunnlag_oracle_rdap_bemanning   TO querychat;
GRANT SELECT ON querychat.ki_grunnlag_oracle_rdap_hr_mndverk  TO querychat;
GRANT SELECT ON querychat.ki_grunnlag_oracle_rdap_liggetimer  TO querychat;
GRANT SELECT ON querychat.ki_grunnlag_oracle_rdap_okonomidata TO querychat;