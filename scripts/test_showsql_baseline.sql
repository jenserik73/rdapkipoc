-- =====================================================================
-- test_showsql_baseline.sql
--
-- Tester DBMS_CLOUD_AI.GENERATE(action => 'showsql') mot QUERYCHAT_PROFILE
-- for å se hvor godt eksisterende COMMENT ON-metadata (comments: true)
-- guider SQL-genereringen i praksis. Brukes som baseline FØR vi evt.
-- legger på ANNOTATIONS.
--
-- Kjøres med sqlcl mot QueryChat-skjemaet:
--   sql /@<tns_alias> @scripts/test_showsql_baseline.sql
-- =====================================================================

SET ECHO ON
SET PAGES 200
SET LONG 10000
SET LONGCHUNKSIZE 10000

PROMPT
PROMPT === Test 1: HELSEFORETAK via fullt navn (tester ALIASES-behov) ===
PROMPT Prompt: "Hvor mange sykepleiere var planlagt i uke 10 2024 ved Oslo universitetssykehus?"
PROMPT Forventning: HELSEFORETAK = 'OUSHF', STILLINGSKATEGORI = 'Sykepleier',
PROMPT              AAR = 2024, ISO_UKE = 10, tabell BEMANNING, kolonne SUM_BEMANNING.
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt       => 'Hvor mange sykepleiere var planlagt i uke 10 2024 ved Oslo universitetssykehus?',
  profile_name => 'QUERYCHAT_PROFILE',
  action       => 'showsql'
) AS generert_sql
FROM DUAL;

PROMPT
PROMPT === Test 2: Periode-filtrering med forretningslogikk fra kommentar ===
PROMPT Prompt: "Hva er gjennomsnittslonn for sykepleiere hittil i aar?"
PROMPT Forventning: bruker BELOEP/MAANEDSVERK_BRUTTO med NULLIF-formelen fra kommentaren,
PROMPT              filtrerer paa "hittil i aar" via TRUNC(periode_arbeidet/100) = EXTRACT(YEAR FROM SYSDATE).
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt       => 'Hva er gjennomsnittslonn for sykepleiere hittil i aar?',
  profile_name => 'QUERYCHAT_PROFILE',
  action       => 'showsql'
) AS generert_sql
FROM DUAL;

PROMPT
PROMPT === Test 3: Unngaa tekniske kolonner (tester at advarsler i kommentar respekteres) ===
PROMPT Prompt: "Vis siste oppdateringstidspunkt og liggetimer per post for OUSHF."
PROMPT Risiko uten god metadata: bruker SIST_KJORETID_DATO eller COLNAME_COL3X_MISSING.
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt       => 'Vis siste oppdateringstidspunkt og liggetimer per post for OUSHF.',
  profile_name => 'QUERYCHAT_PROFILE',
  action       => 'showsql'
) AS generert_sql
FROM DUAL;

PROMPT
PROMPT === Ferdig ===
PROMPT Noter ned resultatene. Neste script (test_annotations_aliases.sql) legger
PROMPT paa ANNOTATIONS (ALIASES ...) for HELSEFORETAK og kjorer Test 1 paa nytt
PROMPT for direkte sammenligning.