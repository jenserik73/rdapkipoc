-- =====================================================================
-- test_agent_feedback_recon.sql
--
-- Rent informativt/read-only rekognoseringsscript - INGEN side-effekter.
-- Maalet er aa avklare:
--   1. Finnes DBMS_CLOUD_AI.FEEDBACK og hva er signaturen?
--   2. Finnes DBMS_CLOUD_AI_AGENT-pakken, og hvilke subprogrammer har den?
--   3. Hva er strukturen paa QUERYCHAT_FEEDBACK, og hva ligger i de 7 radene?
--   4. Finnes relevante CLOUD_AI/AGENT/CONVERSATION-views vi kan bruke
--      til aa hente sql_id (krevd av FEEDBACK-prosedyren)?
--   5. Finnes FEEDBACK-vektorindeksen allerede (skal vaere nei foerst)?
--
-- Basert paa resultatet designer vi neste script (faktisk test av
-- FEEDBACK og evt. et minimalt agent-team).
--
-- Ingen PROMPT rett foran SELECT (kjent sqlcl-bug) - bruker /* */.
--
-- Kjøres med sqlcl mot QueryChat-skjemaet:
--   sql /@<tns_alias> @scripts/test_agent_feedback_recon.sql
-- =====================================================================

SET ECHO ON
SET PAGES 200
SET LONG 5000
SET LONGCHUNKSIZE 5000
COLUMN argument_name FORMAT A25
COLUMN data_type FORMAT A20
COLUMN object_name FORMAT A30
COLUMN column_name FORMAT A30

SELECT /* 1a. Finnes DBMS_CLOUD_AI_AGENT-pakken? */ owner, object_name, object_type, status FROM all_objects WHERE object_name = 'DBMS_CLOUD_AI_AGENT';

SELECT /* 1b. Subprogrammer i DBMS_CLOUD_AI_AGENT */ DISTINCT object_name FROM all_arguments WHERE package_name = 'DBMS_CLOUD_AI_AGENT' ORDER BY object_name;

SELECT /* 2a. Signatur for DBMS_CLOUD_AI.FEEDBACK */ argument_name, data_type, in_out, position, defaulted FROM all_arguments WHERE package_name = 'DBMS_CLOUD_AI' AND object_name = 'FEEDBACK' ORDER BY position;

SELECT /* 2b. Alle subprogrammer i DBMS_CLOUD_AI som inneholder FEEDBACK/CONVERSATION */ DISTINCT object_name FROM all_arguments WHERE package_name = 'DBMS_CLOUD_AI' AND (object_name LIKE '%FEEDBACK%' OR object_name LIKE '%CONVERSATION%') ORDER BY object_name;

SELECT /* 3a. Struktur paa QUERYCHAT_FEEDBACK */ column_name, data_type, data_length, nullable FROM user_tab_columns WHERE table_name = 'QUERYCHAT_FEEDBACK' ORDER BY column_id;

SELECT /* 3b. Eksisterende feedback-rader (alle 7) */ * FROM querychat_feedback FETCH FIRST 10 ROWS ONLY;

SELECT /* 4a. CLOUD_AI/AGENT/CONVERSATION-views tilgjengelig */ view_name FROM user_views WHERE view_name LIKE '%CLOUD_AI%' OR view_name LIKE '%AGENT%' OR view_name LIKE '%CONVERSATION%' ORDER BY view_name;

SELECT /* 4b. Synonymer som kan peke til SYS-views (USER_ prefiks mangler ofte for nyere features) */ synonym_name, table_owner, table_name FROM all_synonyms WHERE owner = 'PUBLIC' AND (synonym_name LIKE '%CLOUD_AI%' OR synonym_name LIKE '%AGENT%') ORDER BY synonym_name;

SELECT /* 5. Finnes FEEDBACK-vektorindeksen allerede? (forventer 0 rader) */ index_name, table_name FROM user_indexes WHERE index_name LIKE '%FEEDBACK_VECINDEX%';

SELECT /* 6. Generell EXECUTE-tilgang - hvilke CLOUD_AI-relaterte pakker kan jeg kjore? */ table_name AS package_name, privilege FROM user_tab_privs WHERE table_name LIKE '%CLOUD_AI%' ORDER BY table_name;