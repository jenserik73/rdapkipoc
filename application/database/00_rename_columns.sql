-- =============================================================
-- 00_rename_columns.sql
-- Renser alle kolonnenavn i querychat:
--   1. Norske tegn (Æ/Ø/Å) → ae/oe/aa
--   2. Tre understrek ___ → én _
--   3. To understrek __  → én _
--   4. Norske tegn i midten av ord (Ø→O, Å→A, Æ→AE)
--
-- Kjør som ADMIN eller eier av querychat.
-- Sjekk avhengigheter FØRST — se bunnen av filen.
-- =============================================================


-- ── KI_GRUNNLAG_ORACLE_RDAP_BEMANNING ────────────────────────
-- ÅR → aar
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_bemanning
  RENAME COLUMN "ÅR" TO aar;


-- ── KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK ───────────────────────
-- FUNKSJONSOMRÅDE → funksjonsomraade
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_hr_mndverk
  RENAME COLUMN "FUNKSJONSOMRÅDE" TO funksjonsomraade;

-- LØNNSGRUPPE → loennsgruppe
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_hr_mndverk
  RENAME COLUMN "LØNNSGRUPPE" TO loennsgruppe;

-- AVTALT_DAGSVERK___BRUTTO → avtalt_dagsverk_brutto
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_hr_mndverk
  RENAME COLUMN avtalt_dagsverk___brutto TO avtalt_dagsverk_brutto;

-- MÅNEDSVERK___BRUTTO → maanedsverk_brutto
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_hr_mndverk
  RENAME COLUMN "MÅNEDSVERK___BRUTTO" TO maanedsverk_brutto;

-- AVTALT_DAGSVERK___NETTO → avtalt_dagsverk_netto
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_hr_mndverk
  RENAME COLUMN avtalt_dagsverk___netto TO avtalt_dagsverk_netto;

-- MÅNEDSVERK___NETTO → maanedsverk_netto
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_hr_mndverk
  RENAME COLUMN "MÅNEDSVERK___NETTO" TO maanedsverk_netto;

-- BELØP → beloep
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_hr_mndverk
  RENAME COLUMN "BELØP" TO beloep;


-- ── KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER ───────────────────────
-- INNLAGT_DØGN_LT → innlagt_dogn_lt
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "INNLAGT_DØGN_LT" TO innlagt_dogn_lt;

-- INNLAGT_DAG_LT — ingen norske tegn, men sjekk om VARCHAR2 bør forbli
-- (ingen rename nødvendig for denne)

-- INNLAGT_LEDSAGER_DØGN_LT → innlagt_ledsager_dogn_lt
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "INNLAGT_LEDSAGER_DØGN_LT" TO innlagt_ledsager_dogn_lt;

-- INNLAGT_LEDSAGER_DAG_LT — ingen norske tegn (ingen rename)

-- INNLAGT_DØGN_FRAVÆR_LT → innlagt_dogn_fravaer_lt
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "INNLAGT_DØGN_FRAVÆR_LT" TO innlagt_dogn_fravaer_lt;

-- INNLAGT_DAG_FRAVÆR_LT → innlagt_dag_fravaer_lt
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "INNLAGT_DAG_FRAVÆR_LT" TO innlagt_dag_fravaer_lt;

-- INNLAGT_LEDSAGER_DØGN_FRAVÆR_LT → innlagt_ledsager_dogn_fravaer_lt
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "INNLAGT_LEDSAGER_DØGN_FRAVÆR_LT" TO innlagt_ledsager_dogn_fravaer_lt;

-- INNLAGT_LEDSAGER_DAG_FRAVÆR_LT → innlagt_ledsager_dag_fravaer_lt
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "INNLAGT_LEDSAGER_DAG_FRAVÆR_LT" TO innlagt_ledsager_dag_fravaer_lt;

-- INNLAGT_DØGN_TEKNISK_LT → innlagt_dogn_teknisk_lt
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "INNLAGT_DØGN_TEKNISK_LT" TO innlagt_dogn_teknisk_lt;

-- INNLAGT_DAG_TEKNISK_LT — ingen norske tegn (ingen rename)

-- INNLAGT_LEDSAGER_DØGN_TEKNISK_LT → innlagt_ledsager_dogn_teknisk_lt
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "INNLAGT_LEDSAGER_DØGN_TEKNISK_LT" TO innlagt_ledsager_dogn_teknisk_lt;

-- INNLAGT_LEDSAGER_DAG_TEKNISK_LT — ingen norske tegn (ingen rename)

-- INNLAGT_DØGN_TEKNISK_FRAVÆR_LT → innlagt_dogn_teknisk_fravaer_lt
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "INNLAGT_DØGN_TEKNISK_FRAVÆR_LT" TO innlagt_dogn_teknisk_fravaer_lt;

-- INNLAGT_DAG_TEKNISK_FRAVÆR_LT → innlagt_dag_teknisk_fravaer_lt
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "INNLAGT_DAG_TEKNISK_FRAVÆR_LT" TO innlagt_dag_teknisk_fravaer_lt;

-- INNLAGT_LEDSAGER_DØGN_TEKNISK_FRAVÆR_LT → innlagt_ledsager_dogn_teknisk_fravaer_lt
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "INNLAGT_LEDSAGER_DØGN_TEKNISK_FRAVÆR_LT"
  TO innlagt_ledsager_dogn_teknisk_fravaer_lt;

-- INNLAGT_LEDSAGER_DAG_TEKNISK_FRAVÆR_LT → innlagt_ledsager_dag_teknisk_fravaer_lt
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "INNLAGT_LEDSAGER_DAG_TEKNISK_FRAVÆR_LT"
  TO innlagt_ledsager_dag_teknisk_fravaer_lt;

-- SIST_KJØRETID_DATO → sist_kjoretid_dato
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_liggetimer
  RENAME COLUMN "SIST_KJØRETID_DATO" TO sist_kjoretid_dato;


-- ── KI_GRUNNLAG_ORACLE_RDAP_OKONOMIDATA ──────────────────────
-- KONTOPLAN_1__NIVÅ → kontoplan_1_nivaa
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_okonomidata
  RENAME COLUMN "KONTOPLAN_1__NIVÅ" TO kontoplan_1_nivaa;

-- KONTOPLAN_2__NIVÅ → kontoplan_2_nivaa
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_okonomidata
  RENAME COLUMN "KONTOPLAN_2__NIVÅ" TO kontoplan_2_nivaa;

-- KONTOPLAN_3__NIVÅ → kontoplan_3_nivaa
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_okonomidata
  RENAME COLUMN "KONTOPLAN_3__NIVÅ" TO kontoplan_3_nivaa;

-- KONTO_ØBAK → konto_obak
ALTER TABLE querychat.ki_grunnlag_oracle_rdap_okonomidata
  RENAME COLUMN "KONTO_ØBAK" TO konto_obak;


-- =============================================================
-- VERIFISERING — kjør etter rename for å bekrefte
-- =============================================================
SELECT table_name, column_name, data_type
FROM   all_tab_columns
WHERE  owner = 'querychat'
  AND  table_name LIKE 'KI_GRUNNLAG_ORACLE_RDAP_%'
  AND  (
         -- Sjekk at ingen norske tegn gjenstår
         REGEXP_LIKE(column_name, '[ÆØÅÆØÅ]')
         -- Sjekk at ingen doble/triple understrek gjenstår
         OR column_name LIKE '%__%'
       )
ORDER  BY table_name, column_id;
-- Forventet: 0 rader


-- =============================================================
-- KJØR DETTE FØRST — sjekk avhengigheter før rename
-- =============================================================
/*
SELECT owner, name, type
FROM   all_dependencies
WHERE  referenced_owner = 'querychat'
  AND  referenced_name LIKE 'KI_GRUNNLAG_ORACLE_RDAP_%'
ORDER  BY type, name;

-- Sjekk views som bruker disse tabellene
SELECT view_name, text
FROM   all_views
WHERE  owner = 'querychat'
ORDER  BY view_name;

-- Sjekk synonymer
SELECT synonym_name, table_name
FROM   all_synonyms
WHERE  table_owner = 'querychat'
ORDER  BY synonym_name;
*/