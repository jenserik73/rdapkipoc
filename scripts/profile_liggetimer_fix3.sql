-- =====================================================================
-- profile_liggetimer_fix3.sql
--
-- profile_liggetimer_fix2.sql feilet for ALLE queries: en "PROMPT <tekst>"
-- rett foran en SELECT svelger SELECT-setningen i denne sqlcl-versjonen,
-- uansett hvor mange PROMPT-linjer som star foran. De queryene som
-- fungerte tidligere hadde en TOM "PROMPT"-linje (uten tekst) forst.
--
-- Losning her: ingen PROMPT rett foran SELECT. Mini-beskrivelser ligger
-- som SQL-kommentarer INNI hver setning (ekkoes av SET ECHO ON).
--
-- Kjøres med sqlcl mot QueryChat-skjemaet:
--   sql /@<tns_alias> @scripts/profile_liggetimer_fix3.sql
-- =====================================================================

SET ECHO ON
SET PAGES 200
COLUMN verdi FORMAT A40
COLUMN antall FORMAT 999999999

SELECT /* AKUTTMOTTAK - 12 distinct */ akuttmottak AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY akuttmottak ORDER BY antall DESC;

SELECT /* ER_TEKNISK - 3 distinct */ er_teknisk AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY er_teknisk ORDER BY antall DESC;

SELECT /* FLYT_TYPE - 5 distinct */ flyt_type AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY flyt_type ORDER BY antall DESC;

SELECT /* OPPHOLDSTYPE - 191 distinct, topp 15 */ oppholdstype AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) GROUP BY oppholdstype ORDER BY antall DESC FETCH FIRST 15 ROWS ONLY;

SELECT /* COLNAME_COL30_MISSING - 11 distinct ikke-null */ colname_col30_missing AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) WHERE colname_col30_missing IS NOT NULL GROUP BY colname_col30_missing ORDER BY antall DESC FETCH FIRST 10 ROWS ONLY;

SELECT /* COLNAME_COL31_MISSING - 7 distinct ikke-null */ colname_col31_missing AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) WHERE colname_col31_missing IS NOT NULL GROUP BY colname_col31_missing ORDER BY antall DESC FETCH FIRST 10 ROWS ONLY;

SELECT /* COLNAME_COL32_MISSING - 5 distinct ikke-null */ colname_col32_missing AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) WHERE colname_col32_missing IS NOT NULL GROUP BY colname_col32_missing ORDER BY antall DESC FETCH FIRST 10 ROWS ONLY;

SELECT /* POLIKLINISK_LT ikke-numerisk vs OPPHOLDSTYPE */ oppholdstype AS verdi, COUNT(*) AS antall FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1) WHERE poliklinisk_lt IS NOT NULL AND NOT REGEXP_LIKE(poliklinisk_lt, '^\s*-?[0-9]+(\.[0-9]+)?\s*$') GROUP BY oppholdstype ORDER BY antall DESC FETCH FIRST 10 ROWS ONLY;