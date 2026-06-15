-- =====================================================================
-- inspect_ki_grunnlag.sql
--
-- Viser kolonner, eksisterende COMMENT ON, og eksisterende ANNOTATIONS
-- for de fire KI_GRUNNLAG_ORACLE_RDAP_*-tabellene som ligger i
-- object_list til QUERYCHAT_PROFILE. Brukes for å velge en god
-- kandidatkolonne til før/etter-showsql-testen.
--
-- Kjøres med sqlcl mot QueryChat-skjemaet:
--   sql /@<tns_alias> @scripts/inspect_ki_grunnlag.sql
-- =====================================================================

SET ECHO ON
SET PAGES 200
COLUMN table_name FORMAT A35
COLUMN column_name FORMAT A30
COLUMN data_type FORMAT A15
COLUMN comments FORMAT A50
COLUMN annotation_name FORMAT A14
COLUMN annotation_value FORMAT A40

PROMPT
PROMPT === 1. Kolonner + datatype ===
SELECT table_name, column_name, data_type, data_length
FROM   user_tab_columns
WHERE  table_name LIKE 'KI_GRUNNLAG_ORACLE_RDAP_%'
ORDER  BY table_name, column_id;

PROMPT
PROMPT === 2. Eksisterende COMMENT ON (tabell og kolonne) ===
SELECT table_name, NULL AS column_name, comments
FROM   user_tab_comments
WHERE  table_name LIKE 'KI_GRUNNLAG_ORACLE_RDAP_%'
AND    comments IS NOT NULL
UNION ALL
SELECT table_name, column_name, comments
FROM   user_col_comments
WHERE  table_name LIKE 'KI_GRUNNLAG_ORACLE_RDAP_%'
AND    comments IS NOT NULL
ORDER  BY 1, 2;

PROMPT
PROMPT === 3. Eksisterende ANNOTATIONS (tabell og kolonne) ===
SELECT object_name, column_name, annotation_name, annotation_value
FROM   user_annotations_usage
WHERE  object_name LIKE 'KI_GRUNNLAG_ORACLE_RDAP_%'
ORDER  BY object_name, column_name, annotation_name;

PROMPT
PROMPT === Ferdig ===