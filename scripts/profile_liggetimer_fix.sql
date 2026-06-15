-- =====================================================================
-- profile_liggetimer_fix.sql
--
-- Fikser steg 1 (ORA-00904: COLUMN_ID finnes ikke i
-- USER_TAB_COL_STATISTICS) og steg 2 (sqlcl tolket multi-linje
-- SELECT/FROM/GROUP BY/ORDER BY feil) fra profile_liggetimer.sql.
-- Alle spørringer er nå enlinjes for å unngå parsing-problemer.
--
-- Kjøres med sqlcl mot QueryChat-skjemaet:
--   sql /@<tns_alias> @scripts/profile_liggetimer_fix.sql
-- =====================================================================

SET ECHO ON
SET PAGES 200
COLUMN column_name FORMAT A35
COLUMN verdi FORMAT A40
COLUMN antall FORMAT 999999999

PROMPT
PROMPT === 1. Kolonnestatistikk (fikset: ORDER BY column_name) ===
SELECT column_name, num_distinct, num_nulls, avg_col_len, to_char(last_analyzed, 'YYYY-MM-DD') AS last_analyzed FROM user_tab_col_statistics WHERE table_name = 'KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER' ORDER BY column_name;

PROMPT
PROMPT === 2. Distinct-verdier, lavkardinalitet-kolonner (enlinjes) ===
PROMPT --- AKUTTMOTTAK ---
SELECT akuttmottak AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY akuttmottak ORDER BY antall DESC;

PROMPT --- ER_TEKNISK ---
SELECT er_teknisk AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY er_teknisk ORDER BY antall DESC;

PROMPT --- FLYT_TYPE ---
SELECT flyt_type AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY flyt_type ORDER BY antall DESC;

PROMPT --- OPPHOLDSTYPE ---
SELECT oppholdstype AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY oppholdstype ORDER BY antall DESC;

PROMPT --- LOKALISERING (topp 15) ---
SELECT lokalisering AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY lokalisering ORDER BY antall DESC FETCH FIRST 15 ROWS ONLY;

PROMPT
PROMPT === 3. Bonus: faktisk innhold i COLNAME_COL3X_MISSING (siden de IKKE er tomme) ===
PROMPT --- COLNAME_COL30_MISSING (topp 10 ikke-null) ---
SELECT colname_col30_missing AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) WHERE colname_col30_missing IS NOT NULL GROUP BY colname_col30_missing ORDER BY antall DESC FETCH FIRST 10 ROWS ONLY;

PROMPT --- COLNAME_COL31_MISSING (topp 10 ikke-null) ---
SELECT colname_col31_missing AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) WHERE colname_col31_missing IS NOT NULL GROUP BY colname_col31_missing ORDER BY antall DESC FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT === 4. Eksempler paa ikke-numerisk POLIKLINISK_LT (forklarer 11.6%-funnet) ===
SELECT poliklinisk_lt AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) WHERE poliklinisk_lt IS NOT NULL AND NOT REGEXP_LIKE(poliklinisk_lt, '^\s*-?[0-9]+(\.[0-9]+)?\s*$') GROUP BY poliklinisk_lt ORDER BY antall DESC FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT === Ferdig ===