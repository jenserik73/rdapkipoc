-- Migration 20: AI-profil katalog + brukertilgang
-- QueryChat NL2SQL SaaS
--
-- DBMS_CLOUD_AI-profiler er databaseobjekter (opprettet via
-- DBMS_CLOUD_AI.CREATE_PROFILE) og har ingen brukervennlig admin-API i ADB.
-- Disse tabellene er QueryChats EGEN katalog over slike profiler, slik at
-- admin-UI kan liste/redigere dem, og slik at vi kan styre per-bruker
-- hvilke profiler en bruker har lov til å bruke i chat.
--
-- qc_ai_profiles.profile_name MÅ matche navnet brukt i
-- DBMS_CLOUD_AI.CREATE_PROFILE(profile_name => ...) eksakt.

CREATE TABLE qc_ai_profiles (
    id              VARCHAR2(32)   NOT NULL,
    profile_name    VARCHAR2(128)  NOT NULL,
    display_name    VARCHAR2(255)  NOT NULL,
    description     VARCHAR2(1000),
    provider        VARCHAR2(50)   DEFAULT 'oci' NOT NULL,
    credential_name VARCHAR2(128)  DEFAULT 'OCI_GEN_AI_CRED' NOT NULL,
    model           VARCHAR2(255)  NOT NULL,
    oci_compartment_id VARCHAR2(255),
    region          VARCHAR2(50)   DEFAULT 'eu-frankfurt-2',
    max_tokens      NUMBER         DEFAULT 1024,
    temperature     NUMBER(3,2)    DEFAULT 0,
    enable_sources  CHAR(1)        DEFAULT 'Y' CHECK (enable_sources IN ('Y','N')),
    annotations     CHAR(1)        DEFAULT 'Y' CHECK (annotations IN ('Y','N')),
    comments        CHAR(1)        DEFAULT 'Y' CHECK (comments IN ('Y','N')),
    case_sensitive_values CHAR(1)  DEFAULT 'N' CHECK (case_sensitive_values IN ('Y','N')),
    source_language VARCHAR2(10)   DEFAULT 'no',
    target_language VARCHAR2(10)   DEFAULT 'no',
    object_list     CLOB           NOT NULL,  -- JSON-array: [{"owner":"QUERYCHAT","name":"TABELL"}]
    is_active       CHAR(1)        DEFAULT 'Y' CHECK (is_active IN ('Y','N')),
    is_default      CHAR(1)        DEFAULT 'N' CHECK (is_default IN ('Y','N')),
    sync_status     VARCHAR2(20)   DEFAULT 'PENDING' CHECK (sync_status IN ('PENDING','SYNCED','ERROR')),
    sync_error      VARCHAR2(2000),
    created_by      VARCHAR2(32),
    created_at      TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_by      VARCHAR2(32),
    updated_at      TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_qc_ai_profiles PRIMARY KEY (id),
    CONSTRAINT uq_qc_ai_profiles_name UNIQUE (profile_name)
);

COMMENT ON TABLE  qc_ai_profiles                  IS 'Katalog over DBMS_CLOUD_AI-profiler administrert via QueryChat admin-UI';
COMMENT ON COLUMN qc_ai_profiles.profile_name      IS 'Eksakt navn brukt i DBMS_CLOUD_AI.CREATE_PROFILE - kan ikke endres etter opprettelse';
COMMENT ON COLUMN qc_ai_profiles.object_list       IS 'JSON-array med {owner,name}-objekter denne profilen får spørre mot';
COMMENT ON COLUMN qc_ai_profiles.sync_status       IS 'PENDING = ikke synket til ADB ennå. SYNCED = matcher DBMS_CLOUD_AI. ERROR = siste synk feilet, se sync_error';
COMMENT ON COLUMN qc_ai_profiles.is_default        IS 'Y for profilen som brukes når en bruker ikke har valgt noen selv. Kun én rad bør ha Y.';

-- Sikrer maks én default-profil
CREATE UNIQUE INDEX uq_qc_ai_profiles_one_default
    ON qc_ai_profiles (CASE WHEN is_default = 'Y' THEN 'Y' END);

-- ─────────────────────────────────────────────────────────────────────────────
-- Bruker-tilgang til AI-profiler (mange-til-mange)
CREATE TABLE qc_user_ai_profiles (
    user_id       VARCHAR2(32) NOT NULL,
    ai_profile_id VARCHAR2(32) NOT NULL,
    granted_by    VARCHAR2(32),
    granted_at    TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_qc_user_ai_profiles PRIMARY KEY (user_id, ai_profile_id),
    CONSTRAINT fk_user_ai_profiles_user
        FOREIGN KEY (user_id) REFERENCES qc_users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_ai_profiles_profile
        FOREIGN KEY (ai_profile_id) REFERENCES qc_ai_profiles(id) ON DELETE CASCADE
);

COMMENT ON TABLE qc_user_ai_profiles IS 'Hvilke AI-profiler en bruker har tillatelse til å velge i chat';

-- ─────────────────────────────────────────────────────────────────────────────
-- Lagre brukerens sist/aktivt valgte profil (separat fra tilgangstabellen,
-- siden "har tilgang til" og "bruker akkurat nå" er to ulike ting)
CREATE TABLE qc_user_active_ai_profile (
    user_id       VARCHAR2(32) NOT NULL,
    ai_profile_id VARCHAR2(32) NOT NULL,
    updated_at    TIMESTAMP    DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_qc_user_active_ai_profile PRIMARY KEY (user_id),
    CONSTRAINT fk_active_profile_user
        FOREIGN KEY (user_id) REFERENCES qc_users(id) ON DELETE CASCADE,
    CONSTRAINT fk_active_profile_profile
        FOREIGN KEY (ai_profile_id) REFERENCES qc_ai_profiles(id) ON DELETE CASCADE
);

COMMENT ON TABLE qc_user_active_ai_profile IS 'Brukerens for tiden valgte AI-profil (én rad per bruker)';

COMMIT;
