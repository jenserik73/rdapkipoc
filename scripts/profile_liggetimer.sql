-- =====================================================================
-- profile_liggetimer.sql
--
-- Dataprofilering av KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER (23M rader).
-- Maalet er aa avdekke informasjon som boer inn som ANNOTATIONS/COMMENT
-- (faktiske verdisett, datakvalitetsavvik, kryss-tabell-konsistens) -
-- akkurat den typen funn som STILLINGSGRUPPE-eksempelet viste verdien av.
--
-- Bruker i hovedsak DBA/USER_TAB_COL_STATISTICS (fra DBMS_STATS, raskt,
-- ingen full scan) + SAMPLE(1) for distinct-verdier paa lavkardinalitet-
-- kolonner (1% av 23M = ~230k rader, mer enn nok for kategoriske felt).
--
-- Kjøres med sqlcl mot QueryChat-skjemaet:
--   sql /@<tns_alias> @scripts/profile_liggetimer.sql
--
-- Estimert kjoretid: under et minutt (stats-delen er instant, SAMPLE-
-- delen er lett). Steg 5 (full scan av "_LT"-kolonner) kan ta lengre tid
-- - kjor den separat om du vil hoppe over.
-- =====================================================================

SET ECHO ON
SET PAGES 200

PROMPT
PROMPT === 1. Kolonnestatistikk fra DBMS_STATS (rask, ingen full scan) ===
COLUMN column_name FORMAT A35
SELECT column_name, num_distinct, num_nulls, avg_col_len,
       to_char(last_analyzed, 'YYYY-MM-DD') AS last_analyzed
FROM   user_tab_col_statistics
WHERE  table_name = 'KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER'
ORDER  BY column_id;

PROMPT
PROMPT --------------------------------------------------------------------
PROMPT Hvis NUM_DISTINCT ser foreldet/feil ut, kan statistikk oppdateres med:
PROMPT   EXEC DBMS_STATS.GATHER_TABLE_STATS('QUERYCHAT','KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER');
PROMPT --------------------------------------------------------------------

PROMPT
PROMPT === 2. Faktiske distinct-verdier for lavkardinalitet-kolonner (SAMPLE 1%) ===
PROMPT Disse er kandidater for ALIASES/DESCRIPTION-annotasjoner med gyldige verdier.
COLUMN verdi FORMAT A40
COLUMN antall FORMAT 999999999

PROMPT --- AKUTTMOTTAK ---
SELECT akuttmottak AS verdi, COUNT(*) AS antall
FROM   ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1)
GROUP  BY akuttmottak
ORDER  BY antall DESC;

PROMPT --- ER_TEKNISK ---
SELECT er_teknisk AS verdi, COUNT(*) AS antall
FROM   ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1)
GROUP  BY er_teknisk
ORDER  BY antall DESC;

PROMPT --- FLYT_TYPE ---
SELECT flyt_type AS verdi, COUNT(*) AS antall
FROM   ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1)
GROUP  BY flyt_type
ORDER  BY antall DESC;

PROMPT --- OPPHOLDSTYPE ---
SELECT oppholdstype AS verdi, COUNT(*) AS antall
FROM   ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1)
GROUP  BY oppholdstype
ORDER  BY antall DESC;

PROMPT --- LOKALISERING (kan ha hoy kardinalitet - bare topp 15) ---
SELECT lokalisering AS verdi, COUNT(*) AS antall
FROM   ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1)
GROUP  BY lokalisering
ORDER  BY antall DESC
FETCH FIRST 15 ROWS ONLY;

PROMPT
PROMPT === 3. Verifiser "tekniske systemkolonner uten innhold" (COLNAME_COL3X_MISSING) ===
PROMPT Kommentaren paastaar disse er tomme. La oss bekrefte (raskt med SAMPLE).
SELECT
  COUNT(*) AS rader_i_sample,
  COUNT(colname_col30_missing) AS col30_ikke_null,
  COUNT(colname_col31_missing) AS col31_ikke_null,
  COUNT(colname_col32_missing) AS col32_ikke_null
FROM ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1);

PROMPT
PROMPT === 4. Sjekk SIST_KJORETID_DATO - format og verdiomraade ===
PROMPT Kolonnen er VARCHAR2 men kommentaren sier den representerer en dato/tidspunkt.
SELECT sist_kjoretid_dato AS verdi, COUNT(*) AS antall
FROM   ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1)
GROUP  BY sist_kjoretid_dato
ORDER  BY antall DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT === 5. (Tyngre - full scan) Datakvalitet paa VARCHAR2 "_LT"-kolonner ===
PROMPT Kommentaren sier INNLAGT_DOGN_LT/INNLAGT_DAG_LT/POLIKLINISK_LT er VARCHAR2
PROMPT med tallverdier - bruk TO_NUMBER ved SUM. Sjekk om noen rader har
PROMPT ikke-numeriske eller NULL-verdier som ville feile TO_NUMBER().
PROMPT Dette er en full scan av 23M rader - kan ta noen minutter.
SELECT
  COUNT(*) AS totalt_antall_rader,
  SUM(CASE WHEN innlagt_dogn_lt IS NULL THEN 1 ELSE 0 END) AS dogn_null,
  SUM(CASE WHEN innlagt_dogn_lt IS NOT NULL
           AND NOT REGEXP_LIKE(innlagt_dogn_lt, '^\s*-?[0-9]+(\.[0-9]+)?\s*$')
      THEN 1 ELSE 0 END) AS dogn_ikke_numerisk,
  SUM(CASE WHEN innlagt_dag_lt IS NULL THEN 1 ELSE 0 END) AS dag_null,
  SUM(CASE WHEN innlagt_dag_lt IS NOT NULL
           AND NOT REGEXP_LIKE(innlagt_dag_lt, '^\s*-?[0-9]+(\.[0-9]+)?\s*$')
      THEN 1 ELSE 0 END) AS dag_ikke_numerisk,
  SUM(CASE WHEN poliklinisk_lt IS NULL THEN 1 ELSE 0 END) AS polikl_null,
  SUM(CASE WHEN poliklinisk_lt IS NOT NULL
           AND NOT REGEXP_LIKE(poliklinisk_lt, '^\s*-?[0-9]+(\.[0-9]+)?\s*$')
      THEN 1 ELSE 0 END) AS polikl_ikke_numerisk
FROM ki_grunnlag_oracle_rdap_liggetimer;

PROMPT
PROMPT === 6. Kryss-tabell-konsistens: HELSEFORETAK-verdier i alle 4 KI_GRUNNLAG-tabeller ===
PROMPT Sjekker om verdisettet er identisk - relevant for delt ALIASES/JOIN COLUMN.
SELECT 'BEMANNING' AS tabell, helseforetak, COUNT(*) AS antall
FROM   ki_grunnlag_oracle_rdap_bemanning SAMPLE(5)
GROUP  BY helseforetak
UNION ALL
SELECT 'HR_MNDVERK', helseforetak, COUNT(*)
FROM   ki_grunnlag_oracle_rdap_hr_mndverk SAMPLE(1)
GROUP  BY helseforetak
UNION ALL
SELECT 'LIGGETIMER', helseforetak, COUNT(*)
FROM   ki_grunnlag_oracle_rdap_liggetimer SAMPLE(1)
GROUP  BY helseforetak
UNION ALL
SELECT 'OKONOMIDATA', helseforetak, COUNT(*)
FROM   ki_grunnlag_oracle_rdap_okonomidata SAMPLE(5)
GROUP  BY helseforetak
ORDER  BY helseforetak, tabell;

PROMPT
PROMPT === Ferdig ===
PROMPT Bruk resultatene til aa:
PROMPT   - Skrive ALIASES/DESCRIPTION-annotasjoner med BEKREFTEDE gyldige verdier
PROMPT     (istedenfor antatte/avledede kategorier som STILLINGSGRUPPE-tilfellet)
PROMPT   - Flagge evt. avvik i COLNAME_COL3X_MISSING / SIST_KJORETID_DATO / _LT-kolonner
PROMPT     som DESCRIPTION-annotasjoner ("X% av radene har Y - filtrer med Z")
PROMPT   - Vurdere om HELSEFORETAK boer ha en delt referanseliste (samme verdier
PROMPT     i alle 4 tabeller -> god kandidat for konsistent ALIASES paa tvers)