-- =====================================================================
-- test_select_ai_feedback.sql
--
-- Tester DBMS_CLOUD_AI.FEEDBACK med et kjent caseeksempel: tidligere
-- viste vi at "STILLINGSGRUPPE = 'Sykepleier'" er en INKOMPLETT
-- tolkning av "sykepleiere totalt" (mangler 7 andre verdier i IN-listen).
--
-- Steg:
--   1. Baseline: kjor et NYTT prompt (ikke brukt tidligere) som rammer
--      samme STILLINGSGRUPPE-problem, noter generert SQL
--   2. Gi NEGATIV feedback via DBMS_CLOUD_AI.FEEDBACK: sql_text = den
--      ufullstendige varianten (= 'Sykepleier'), feedback_content =
--      korrekt IN(...)-versjon + forklaring
--   3. Verifiser at <profil>_FEEDBACK_VECINDEX ble opprettet
--   4. Kjor SAMME prompt som steg 1 paa nytt - sammenlign
--   5. Kjor et TREDJE, litt annerledes prompt (samme tema) - tester om
--      feedback generaliserer utover eksakt prompt-match
--
-- Ingen PROMPT rett foran SELECT (kjent sqlcl-bug) - bruker /* */.
--
-- Kjøres med sqlcl mot QueryChat-skjemaet:
--   sql /@<tns_alias> @scripts/test_select_ai_feedback.sql
-- =====================================================================

SET ECHO ON
SET PAGES 200
SET LONG 10000
SET LONGCHUNKSIZE 10000

SELECT /* 1. Baseline - nytt prompt, samme STILLINGSGRUPPE-tema */ DBMS_CLOUD_AI.GENERATE(
  prompt       => 'Hvor mange aarsverk har sykepleiere totalt ved OUSHF i 2024?',
  profile_name => 'QUERYCHAT_PROFILE',
  action       => 'showsql'
) AS baseline_sql
FROM DUAL;

BEGIN
  /* 2. Gi negativ feedback: ufullstendig SQL -> korrekt SQL med forklaring */
  DBMS_CLOUD_AI.FEEDBACK(
    profile_name     => 'QUERYCHAT_PROFILE',
    sql_text         => 'SELECT SUM(maanedsverk_netto)/12 AS aarsverk FROM ki_grunnlag_oracle_rdap_hr_mndverk WHERE UPPER(stillingsgruppe) = UPPER(''Sykepleier'') AND UPPER(helseforetak) = UPPER(''OUSHF'')',
    feedback_type    => 'negative',
    feedback_content => 'Feil: stillingsgruppe = ''Sykepleier'' er ufullstendig for "sykepleiere totalt". Korrekt SQL: SELECT SUM(maanedsverk_netto)/12 AS aarsverk FROM ki_grunnlag_oracle_rdap_hr_mndverk WHERE UPPER(stillingsgruppe) IN (UPPER(''Sykepleier''), UPPER(''Operasjonssykepleier''), UPPER(''Barn/Pediatrisykepleier''), UPPER(''Anestesisykepleier''), UPPER(''Andre spesialsykepleiere''), UPPER(''Intensivsykepleier''), UPPER(''Jordmor''), UPPER(''Kreft/onkologisykepleier'')) AND UPPER(helseforetak) = UPPER(''OUSHF'')'
  );
END;
/

SELECT /* 3. Verifiser at FEEDBACK_VECINDEX ble opprettet */ index_name, index_type, table_name FROM user_indexes WHERE index_name LIKE '%FEEDBACK_VECINDEX%';

SELECT /* 3b. Sjekk om det finnes en tilhorende vektor-tabell med innhold */ table_name, num_rows FROM user_tables WHERE table_name LIKE '%FEEDBACK%';

SELECT /* 4. Samme prompt som steg 1 paa nytt - sammenlign */ DBMS_CLOUD_AI.GENERATE(
  prompt       => 'Hvor mange aarsverk har sykepleiere totalt ved OUSHF i 2024?',
  profile_name => 'QUERYCHAT_PROFILE',
  action       => 'showsql'
) AS etter_feedback_sql
FROM DUAL;

SELECT /* 5. Litt annerledes prompt, samme tema - tester generalisering */ DBMS_CLOUD_AI.GENERATE(
  prompt       => 'Hva er totalt antall aarsverk for sykepleiergruppen ved Sykehuset Innlandet i 2024?',
  profile_name => 'QUERYCHAT_PROFILE',
  action       => 'showsql'
) AS generalisert_sql
FROM DUAL;