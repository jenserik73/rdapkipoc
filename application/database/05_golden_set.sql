-- =============================================================
-- 05_golden_set.sql  — rene kolonnenavn etter 00_rename_columns.sql
-- =============================================================

-- Test 1: HR — gjennomsnittsloenn per HF hittil i aar
SELECT helseforetak,
       ROUND(SUM(beloep) / NULLIF(SUM(maanedsverk_brutto), 0), 0) AS gjennomsnittsloenn_nok,
       ROUND(SUM(maanedsverk_brutto), 2)                           AS mndverk_brutto
FROM   querychat.ki_grunnlag_oracle_rdap_hr_mndverk
WHERE  maanedsverk_brutto > 0
  AND  TRUNC(periode_arbeidet / 100) = EXTRACT(YEAR FROM SYSDATE)
GROUP  BY helseforetak
ORDER  BY gjennomsnittsloenn_nok DESC;

-- Test 2: HR — aarsverk sykepleiere (netto) per HF
SELECT helseforetak,
       ROUND(SUM(maanedsverk_netto), 2)      AS mndverk_netto,
       ROUND(SUM(maanedsverk_netto) / 12, 2) AS aarsverk
FROM   querychat.ki_grunnlag_oracle_rdap_hr_mndverk
WHERE  stillingsgruppe IN (
         'Sykepleier','Operasjonssykepleier','Barn/Pediatrisykepleier',
         'Anestesisykepleier','Andre spesialsykepleiere',
         'Intensivsykepleier','Jordmor','Kreft/onkologisykepleier'
       )
  AND  TRUNC(periode_arbeidet / 100) = EXTRACT(YEAR FROM SYSDATE)
GROUP  BY helseforetak
ORDER  BY mndverk_netto DESC;

-- Test 3: Bemanning — snitt planlagte vakter og overtid per HF (ukebasert)
SELECT helseforetak,
       ROUND(AVG(sum_bemanning), 1) AS snitt_vakter_per_uke,
       SUM(sum_overtid)             AS total_overtid,
       SUM(sum_ekstra)              AS total_ekstravakter,
       ROUND(
         SUM(sum_gaatt_som_planlagt) / NULLIF(SUM(sum_bemanning), 0) * 100, 1
       )                            AS planlagt_pst
FROM   querychat.ki_grunnlag_oracle_rdap_bemanning
WHERE  aar = EXTRACT(YEAR FROM SYSDATE)
GROUP  BY helseforetak
ORDER  BY snitt_vakter_per_uke DESC;

-- Test 4: Liggetimer — kliniske doegntimer per avdeling siste maaned
-- NB: innlagt_dogn_lt er VARCHAR2 og maa konverteres med TO_NUMBER
SELECT helseforetak,
       avdeling,
       SUM(TO_NUMBER(innlagt_dogn_lt)) AS dogn_liggetimer,
       SUM(TO_NUMBER(innlagt_dag_lt))  AS dag_liggetimer,
       SUM(innlagt_dogn_fravaer_lt)    AS fravaer_timer
FROM   querychat.ki_grunnlag_oracle_rdap_liggetimer
--WHERE  TRUNC(dato, 'MM') = TRUNC(ADD_MONTHS(SYSDATE, -1), 'MM')
  --AND  (er_teknisk IS NULL OR er_teknisk != 'J')
GROUP  BY helseforetak, avdeling
ORDER  BY dogn_liggetimer DESC
FETCH  FIRST 15 ROWS ONLY;

-- Test 5: Okonomi — budsjettavvik per klinikk hittil i aar
SELECT helseforetak,
       klinikk,
       SUM(budsjett)                                                     AS budsjett_nok,
       SUM(faktisk)                                                      AS faktisk_nok,
       SUM(faktisk) - SUM(budsjett)                                      AS avvik_nok,
       ROUND((SUM(faktisk)-SUM(budsjett))/NULLIF(SUM(budsjett),0)*100,1) AS avvik_pst
FROM   querychat.ki_grunnlag_oracle_rdap_okonomidata
WHERE  EXTRACT(YEAR FROM periode) = EXTRACT(YEAR FROM SYSDATE)
GROUP  BY helseforetak, klinikk
ORDER  BY avvik_nok;