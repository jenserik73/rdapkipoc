-- =====================================================================
-- test_annotations.sql
--
-- Verifiserer at Oracle 23ai schema annotations fungerer på ADB-
-- instansen (oc19 / Sovereign Cloud), og at Select AI kan ta dem i
-- bruk via "annotations": true på AI-profilen.
--
-- Kjøres med sqlcl mot QueryChat-skjemaet:
--   sql /@<tns_alias> @scripts/test_annotations.sql
--
-- Scriptet rydder opp etter seg (DROP TABLE på slutten).
-- =====================================================================

SET ECHO ON
SET PAGES 100
SET LINES 200
COLUMN object_name FORMAT A22
COLUMN object_type FORMAT A8
COLUMN column_name FORMAT A15
COLUMN annotation_name FORMAT A14
COLUMN annotation_value FORMAT A35

PROMPT
PROMPT === 1. Databaseversjon ===
SELECT version_full FROM PRODUCT_COMPONENT_VERSION WHERE product LIKE 'Oracle%';

PROMPT
PROMPT === 2. Opprett testtabell med tabell- og kolonneannotasjoner ===
DROP TABLE qc_annotation_test PURGE;

CREATE TABLE qc_annotation_test (
    id     NUMBER
           ANNOTATIONS (Identity, ALIASES 'rad-id, nøkkel'),
    navn   VARCHAR2(50)
           ANNOTATIONS (ALIASES 'fornavn, kundenavn', DESCRIPTION 'Visningsnavn for kunden'),
    belop  NUMBER
           ANNOTATIONS (UNITS 'NOK')
)
ANNOTATIONS (DESCRIPTION 'Testtabell for QueryChat schema annotations', "JOIN COLUMN" 'id');

PROMPT
PROMPT === 3. Legg til en annotasjon med ALTER (simulerer admin-UI-redigering) ===
ALTER TABLE qc_annotation_test MODIFY belop ANNOTATIONS (ADD DESCRIPTION 'Totalbeløp på ordren, eks. mva');

PROMPT
PROMPT === 4. Slett en annotasjon med ALTER ... DROP (simulerer fjerning via admin-UI) ===
ALTER TABLE qc_annotation_test MODIFY id ANNOTATIONS (DROP Identity);

PROMPT
PROMPT === 5. Objekt-nivå annotasjoner (tabell) ===
SELECT object_name, object_type, annotation_name, annotation_value
FROM   user_annotations_usage
WHERE  object_name = 'QC_ANNOTATION_TEST'
AND    column_name IS NULL
ORDER  BY annotation_name;

PROMPT
PROMPT === 6. Kolonne-nivå annotasjoner ===
SELECT object_name, object_type, column_name, annotation_name, annotation_value
FROM   user_annotations_usage
WHERE  object_name = 'QC_ANNOTATION_TEST'
AND    column_name IS NOT NULL
ORDER  BY column_name, annotation_name;

PROMPT
PROMPT === 7. Select AI-profiler tilgjengelig i skjemaet ===
SELECT profile_name, status FROM USER_CLOUD_AI_PROFILES;

PROMPT
PROMPT --------------------------------------------------------------------
PROMPT NESTE STEG (manuelt, gjør IKKE automatisk her):
PROMPT   1. Sett profil-attributt:
PROMPT      BEGIN
PROMPT        DBMS_CLOUD_AI.SET_ATTRIBUTE(
PROMPT          profile_name    => '<PROFILNAVN>',
PROMPT          attribute_name  => 'annotations',
PROMPT          attribute_value => 'true'
PROMPT        );
PROMPT      END;
PROMPT      /
PROMPT
PROMPT   2. Legg qc_annotation_test til object_list (eller bruk en
PROMPT      eksisterende tabell du har annotert), og kjør showsql:
PROMPT      SELECT DBMS_CLOUD_AI.GENERATE(
PROMPT        prompt       => 'Hvor mange rader har vi i testtabellen?',
PROMPT        profile_name => '<PROFILNAVN>',
PROMPT        action       => 'showsql'
PROMPT      ) FROM DUAL;
PROMPT
PROMPT   3. Sammenlign generert SQL/forklaring med og uten
PROMPT      "annotations": true for å se effekten av DESCRIPTION/ALIASES.
PROMPT --------------------------------------------------------------------

PROMPT
PROMPT === 8. Rydd opp ===
DROP TABLE qc_annotation_test PURGE;

PROMPT
PROMPT === Ferdig ===