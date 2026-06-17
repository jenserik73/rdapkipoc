-- =====================================================================
-- Migrasjon: qc_object_annotations
--
-- Metadatatabell for NL2SQL-annotasjoner (admin-redigerbar), jf.
-- arkitektur_qc_object_annotations.md avsnitt 2.
--
-- sync_target styrer hvor en rad synkes naar status='AKTIV':
--   COMMENT    -> COMMENT ON TABLE/COLUMN
--   ANNOTATION -> ALTER TABLE ... [MODIFY <col>] ANNOTATIONS (ADD/DROP ...)
--   NONE       -> ingen DDL, kun internt notat (notat_type)
--
-- id er VARCHAR2(32) (ikke RAW) - oracledb kan ikke binde bytes til RAW
-- i plain SQL, samme mønster som øvrige QC_*-tabeller.
-- =====================================================================

CREATE TABLE qc_object_annotations (
  id               VARCHAR2(32)  NOT NULL,
  object_owner     VARCHAR2(128) NOT NULL,
  object_name      VARCHAR2(128) NOT NULL,
  column_name      VARCHAR2(128),                  -- NULL = tabellnivaa
  sync_target      VARCHAR2(16)  NOT NULL,         -- 'COMMENT' | 'ANNOTATION' | 'NONE'
  annotation_name  VARCHAR2(128),                  -- kun for sync_target='ANNOTATION':
                                                    -- DESCRIPTION, ALIASES, UNITS, "JOIN COLUMN", ...
  annotation_value VARCHAR2(4000) NOT NULL,
  notat_type       VARCHAR2(32),                   -- kun for sync_target='NONE':
                                                    -- 'DATAKVALITET' | 'VIEW_KANDIDAT' | 'TODO'
  status           VARCHAR2(16) DEFAULT 'AKTIV' NOT NULL,  -- 'AKTIV' | 'UTKAST' | 'ARKIVERT'
  updated_by       VARCHAR2(32),
  updated_at       TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT qc_oa_pk PRIMARY KEY (id),
  CONSTRAINT qc_oa_sync_target_chk
    CHECK (sync_target IN ('COMMENT','ANNOTATION','NONE')),
  CONSTRAINT qc_oa_status_chk
    CHECK (status IN ('AKTIV','UTKAST','ARKIVERT')),
  CONSTRAINT qc_oa_annotation_name_chk
    CHECK (sync_target != 'ANNOTATION' OR annotation_name IS NOT NULL),
  CONSTRAINT qc_oa_notat_type_chk
    CHECK (sync_target != 'NONE' OR notat_type IS NOT NULL)
);

COMMENT ON TABLE qc_object_annotations IS 'QueryChat admin-metadata: NL2SQL-annotasjoner (COMMENT ON / ANNOTATIONS-syntaks) og interne notater per databaseobjekt/kolonne. Se arkitektur_qc_object_annotations.md.';
COMMENT ON COLUMN qc_object_annotations.sync_target IS 'COMMENT = synk til COMMENT ON; ANNOTATION = synk til ALTER TABLE ... ANNOTATIONS; NONE = internt notat, ingen DDL';
COMMENT ON COLUMN qc_object_annotations.annotation_name IS 'Kun for sync_target=ANNOTATION. Eks: DESCRIPTION, ALIASES, UNITS, "JOIN COLUMN"';
COMMENT ON COLUMN qc_object_annotations.notat_type IS 'Kun for sync_target=NONE. Eks: DATAKVALITET, VIEW_KANDIDAT, TODO';
COMMENT ON COLUMN qc_object_annotations.status IS 'AKTIV = synket til DB; UTKAST = lagret men ikke synket; ARKIVERT = tidligere synket, naa fjernet/deaktivert';

-- Unik per (objekt, kolonne, synk-maal, annotasjonsnavn). NVL haandterer
-- tabellnivaa (column_name NULL) og COMMENT/NONE (annotation_name NULL).
CREATE UNIQUE INDEX qc_oa_uq ON qc_object_annotations (
  object_owner,
  object_name,
  NVL(column_name, '*'),
  sync_target,
  NVL(annotation_name, '*')
);

-- Stotteindeks for "Metadata"-fanens objektliste (slaa opp alt for ett objekt)
CREATE INDEX qc_oa_object_idx ON qc_object_annotations (object_owner, object_name);

-- Stotteindeks for filtrering paa status (f.eks. "vis alle UTKAST")
CREATE INDEX qc_oa_status_idx ON qc_object_annotations (status);

-- =====================================================================
-- Rollback (kommenter inn ved behov):
-- DROP TABLE qc_object_annotations PURGE;
-- =====================================================================
