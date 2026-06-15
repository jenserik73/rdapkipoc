-- =====================================================================
-- inspect_ai_profile.sql
--
-- Viser nåværende attributter og object_list for QUERYCHAT_PROFILE,
-- som grunnlag for å velge en tabell/kolonne til annotations-testen
-- (test_annotations_select_ai.sql).
--
-- Kjøres med sqlcl mot QueryChat-skjemaet:
--   sql /@<tns_alias> @scripts/inspect_ai_profile.sql
-- =====================================================================

SET ECHO ON
SET PAGES 200
SET LINES 200
COLUMN attribute_name FORMAT A25
COLUMN attribute_value FORMAT A100

PROMPT
PROMPT === Profil-attributter ===
SELECT attribute_name, attribute_value
FROM   user_cloud_ai_profile_attributes
WHERE  profile_name = 'QUERYCHAT_PROFILE'
ORDER  BY attribute_name;

PROMPT
PROMPT === object_list (rå JSON, finnes typisk i attribute_value for 'OBJECT_LIST') ===
SELECT attribute_value
FROM   user_cloud_ai_profile_attributes
WHERE  profile_name = 'QUERYCHAT_PROFILE'
AND    attribute_name = 'OBJECT_LIST';

PROMPT
PROMPT === Egne tabeller/views i skjemaet (for å velge testobjekt) ===
SELECT table_name, num_rows
FROM   user_tables
ORDER  BY table_name;

PROMPT
PROMPT === Ferdig ===