-- =====================================================================
-- test_annotations_hr_mndverk.sql
--
-- Test 2 i test_showsql_baseline.sql avdekket to feil selv om
-- informasjonen finnes i COMMENT ON:
--   1. AVG(beloep) brukt istedenfor SUM(beloep)/NULLIF(SUM(maanedsverk_brutto),0)
--   2. STILLINGSGRUPPE = 'Sykepleiere totalt' behandlet som literal verdi
--      (det er en kategori, ikke en faktisk kolonneverdi)
--
-- Dette scriptet legger paa ANNOTATIONS med mer direktiv fraseologi paa
-- de samme to kolonnene, og kjorer samme prompt paa nytt for sammenligning.
--
-- MERK: Dette gjor ALTER TABLE (annotations only, ingen DDL-lock/data-
-- paavirkning) paa en reell tabell i object_list. Annotasjonene fjernes
-- i siste steg (kommentert ut - fjern kommentar hvis du vil rydde opp).
--
-- Kjøres med sqlcl mot QueryChat-skjemaet:
--   sql /@<tns_alias> @scripts/test_annotations_hr_mndverk.sql
-- =====================================================================

SET ECHO ON
SET PAGES 200
SET LONG 10000
SET LONGCHUNKSIZE 10000

PROMPT
PROMPT === 1. Legg paa direktiv ANNOTATIONS paa BELOEP og STILLINGSGRUPPE ===
ALTER TABLE ki_grunnlag_oracle_rdap_hr_mndverk
  MODIFY beloep ANNOTATIONS (
    ADD "JOIN COLUMN" 'maanedsverk_brutto',
    ADD DESCRIPTION 'VIKTIG: For "gjennomsnittslonn" skal AVG(beloep) ALDRI brukes. Korrekt formel: SUM(beloep) / NULLIF(SUM(maanedsverk_brutto), 0), kun for rader der maanedsverk_brutto > 0.'
  );

ALTER TABLE ki_grunnlag_oracle_rdap_hr_mndverk
  MODIFY stillingsgruppe ANNOTATIONS (
    ADD ALIASES 'Sykepleiere totalt er IKKE en kolonneverdi. For "sykepleiere totalt" eller "alle sykepleiere", filtrer med: stillingsgruppe IN (Sykepleier, Operasjonssykepleier, Barn/Pediatrisykepleier, Anestesisykepleier, Andre spesialsykepleiere, Intensivsykepleier, Jordmor, Kreft/onkologisykepleier)'
  );

PROMPT
PROMPT === 2. Verifiser at annotasjonene ligger i dictionary ===
SELECT object_name, column_name, annotation_name, annotation_value
FROM   user_annotations_usage
WHERE  object_name = 'KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK'
ORDER  BY column_name, annotation_name;

PROMPT
PROMPT === 3. Kjor samme prompt som Test 2 i baseline paa nytt ===
PROMPT Prompt: "Hva er gjennomsnittslonn for sykepleiere hittil i aar?"
PROMPT Sammenlign mot baseline:
PROMPT   FOR: AVG(b."BELOEP") ... WHERE ... STILLINGSGRUPPE = 'Sykepleiere totalt'
PROMPT   ETTER (forventet): SUM(beloep)/NULLIF(SUM(maanedsverk_brutto),0) ... STILLINGSGRUPPE IN (...)
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt       => 'Hva er gjennomsnittslonn for sykepleiere hittil i aar?',
  profile_name => 'QUERYCHAT_PROFILE',
  action       => 'showsql'
) AS generert_sql
FROM DUAL;

PROMPT
PROMPT === 4. (Valgfritt) Rydd opp - fjern kommentartegn for aa fjerne testannotasjonene ===
-- ALTER TABLE ki_grunnlag_oracle_rdap_hr_mndverk MODIFY beloep ANNOTATIONS (DROP "JOIN COLUMN", DROP DESCRIPTION);
-- ALTER TABLE ki_grunnlag_oracle_rdap_hr_mndverk MODIFY stillingsgruppe ANNOTATIONS (DROP ALIASES);

PROMPT
PROMPT === Ferdig ===