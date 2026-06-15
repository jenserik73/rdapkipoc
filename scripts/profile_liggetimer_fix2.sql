-- =====================================================================
-- profile_liggetimer_fix2.sql
--
-- Fikser steg 2-3 fra profile_liggetimer_fix.sql. Root cause: sqlcl
-- svelger en SELECT-setning som kommer rett etter TRE PROMPT-linjer i
-- rad (bekreftet reproduserbart - seksjoner med kun to PROMPT-linjer
-- fungerte fint). Hver query her har derfor kun EN PROMPT-linje foran.
--
-- Kjøres med sqlcl mot QueryChat-skjemaet:
--   sql /@<tns_alias> @scripts/profile_liggetimer_fix2.sql
-- =====================================================================

SET ECHO ON
SET PAGES 200
COLUMN verdi FORMAT A40
COLUMN antall FORMAT 999999999

PROMPT --- AKUTTMOTTAK (12 distinct) ---
SELECT akuttmottak AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY akuttmottak ORDER BY antall DESC;

PROMPT --- ER_TEKNISK (3 distinct) ---
SELECT er_teknisk AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY er_teknisk ORDER BY antall DESC;

PROMPT --- FLYT_TYPE (5 distinct) ---
SELECT flyt_type AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY flyt_type ORDER BY antall DESC;

PROMPT --- OPPHOLDSTYPE (191 distinct - topp 15) ---
SELECT oppholdstype AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY oppholdstype ORDER BY antall DESC FETCH FIRST 15 ROWS ONLY;

PROMPT --- COLNAME_COL30_MISSING (11 distinct, ikke-null) ---
SELECT colname_col30_missing AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) WHERE colname_col30_missing IS NOT NULL GROUP BY colname_col30_missing ORDER BY antall DESC FETCH FIRST 10 ROWS ONLY;

PROMPT --- COLNAME_COL31_MISSING (7 distinct, ikke-null) ---
SELECT colname_col31_missing AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) WHERE colname_col31_missing IS NOT NULL GROUP BY colname_col31_missing ORDER BY antall DESC FETCH FIRST 10 ROWS ONLY;

PROMPT --- COLNAME_COL32_MISSING (5 distinct, ikke-null) ---
SELECT colname_col32_missing AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) WHERE colname_col32_missing IS NOT NULL GROUP BY colname_col32_missing ORDER BY antall DESC FETCH FIRST 10 ROWS ONLY;

PROMPT --- Sammenheng: er POLIKLINISK_LT ikke-numerisk korrelert med OPPHOLDSTYPE? ---
SELECT oppholdstype AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) WHERE poliklinisk_lt IS NOT NULL AND NOT REGEXP_LIKE(poliklinisk_lt, '^\s*-?[0-9]+(\.[0-9]+)?\s*$') GROUP BY oppholdstype ORDER BY antall DESC FETCH FIRST 10 ROWS ONLY;

PROMPT === Ferdig ===