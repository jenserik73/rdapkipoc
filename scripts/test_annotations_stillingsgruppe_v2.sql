-- =====================================================================
-- test_annotations_stillingsgruppe_v2.sql
--
-- Forrige test (test_annotations_hr_mndverk.sql) ga delvis resultat:
--   STILLINGSGRUPPE = 'Sykepleiere totalt' (ugyldig) -> 'Sykepleier' (gyldig,
--   men kun EN av flere relevante verdier - mangler resten av kategorien).
--
-- Hypotese: en forklarende setning med kommaseparert liste er vanskeligere
-- aa "kopiere" enn ferdig SQL-syntaks. Dette scriptet:
--   1. Fjerner forrige ALIASES-annotasjon paa STILLINGSGRUPPE
--   2. Legger paa en DESCRIPTION-annotasjon med IN (...) skrevet som
--      gyldig SQL-literal-liste, direktiv fraseologi
--   3. Kjorer samme prompt som forrige test paa nytt
--
-- BELOEP-annotasjonen fra forrige script ROERES IKKE (den fungerte perfekt).
--
-- Kjøres med sqlcl mot QueryChat-skjemaet:
--   sql /@<tns_alias> @scripts/test_annotations_stillingsgruppe_v2.sql
-- =====================================================================

SET ECHO ON
SET PAGES 200
SET LONG 10000
SET LONGCHUNKSIZE 10000

PROMPT
PROMPT === 1. Fjern forrige ALIASES-annotasjon paa STILLINGSGRUPPE ===
ALTER TABLE ki_grunnlag_oracle_rdap_hr_mndverk
  MODIFY stillingsgruppe ANNOTATIONS (DROP ALIASES);

PROMPT
PROMPT === 2. Legg paa DESCRIPTION med ferdig SQL IN(...)-syntaks ===
ALTER TABLE ki_grunnlag_oracle_rdap_hr_mndverk
  MODIFY stillingsgruppe ANNOTATIONS (
    ADD DESCRIPTION 'Verdien "Sykepleiere totalt" finnes IKKE i denne kolonnen - det er en samlekategori. For "sykepleiere totalt" eller "alle sykepleiere", bruk alltid: stillingsgruppe IN (''Sykepleier'', ''Operasjonssykepleier'', ''Barn/Pediatrisykepleier'', ''Anestesisykepleier'', ''Andre spesialsykepleiere'', ''Intensivsykepleier'', ''Jordmor'', ''Kreft/onkologisykepleier'')'
  );

PROMPT
PROMPT === 3. Verifiser annotasjon i dictionary ===
SELECT object_name, column_name, annotation_name, annotation_value
FROM   user_annotations_usage
WHERE  object_name = 'KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK'
AND    column_name = 'STILLINGSGRUPPE'
ORDER  BY annotation_name;

PROMPT
PROMPT === 4. Kjor samme prompt som tidligere paa nytt ===
PROMPT Prompt: "Hva er gjennomsnittslonn for sykepleiere hittil i aar?"
PROMPT Sammenlign mot v1:
PROMPT   v1: ... STILLINGSGRUPPE = 'Sykepleier'  (gyldig, men inkompletti)
PROMPT   v2 (forventet): ... STILLINGSGRUPPE IN ('Sykepleier','Operasjonssykepleier',...)
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt       => 'Hva er gjennomsnittslonn for sykepleiere hittil i aar?',
  profile_name => 'QUERYCHAT_PROFILE',
  action       => 'showsql'
) AS generert_sql
FROM DUAL;

PROMPT
PROMPT === 5. Bonus: test med "totalt"-ordet direkte for aa se om frasen trigges ===
PROMPT Prompt: "Hvor mange aarsverk har sykepleiere totalt i 2024?"
SELECT DBMS_CLOUD_AI.GENERATE(
  prompt       => 'Hvor mange aarsverk har sykepleiere totalt i 2024?',
  profile_name => 'QUERYCHAT_PROFILE',
  action       => 'showsql'
) AS generert_sql
FROM DUAL;

PROMPT
PROMPT === Ferdig ===
PROMPT Hvis v2 fortsatt ikke gir full IN(...)-liste, er det et signal om at
PROMPT denne typen "kategori-til-verdiliste"-mapping kanskje boer handteres
PROMPT som en VIEW (f.eks. v_sykepleiere_totalt) heller enn som annotasjon -
PROMPT siden det er en semantisk regel, ikke bare metadata om kolonnen.