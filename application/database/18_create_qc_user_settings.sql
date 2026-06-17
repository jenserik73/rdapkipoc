-- Migration 18: Brukerinnstillinger
-- QueryChat NL2SQL SaaS

CREATE TABLE qc_settings_defaults (
    key         VARCHAR2(100)  NOT NULL,
    value       VARCHAR2(1000) NOT NULL,
    description VARCHAR2(500),
    category    VARCHAR2(50)   DEFAULT 'general' NOT NULL,
    CONSTRAINT pk_qc_settings_defaults PRIMARY KEY (key)
);

COMMENT ON TABLE  qc_settings_defaults             IS 'Standardverdier for alle brukerinnstillinger';
COMMENT ON COLUMN qc_settings_defaults.key         IS 'Innstillingsnøkkel, f.eks. ui.theme';
COMMENT ON COLUMN qc_settings_defaults.value       IS 'Standardverdi';
COMMENT ON COLUMN qc_settings_defaults.category    IS 'Grupperingskategori for admin-UI: ui | query | notifications';

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE qc_user_settings (
    user_id    VARCHAR2(32)   NOT NULL,
    key        VARCHAR2(100)  NOT NULL,
    value      VARCHAR2(1000) NOT NULL,
    updated_at TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_qc_user_settings PRIMARY KEY (user_id, key),
    CONSTRAINT fk_user_settings_user
        FOREIGN KEY (user_id) REFERENCES qc_users(id) ON DELETE CASCADE,
    CONSTRAINT fk_user_settings_key
        FOREIGN KEY (key) REFERENCES qc_settings_defaults(key)
);

COMMENT ON TABLE  qc_user_settings           IS 'Bruker-spesifikke overstyringer av standardinnstillinger';
COMMENT ON COLUMN qc_user_settings.user_id   IS 'FK til qc_users.id';
COMMENT ON COLUMN qc_user_settings.key       IS 'FK til qc_settings_defaults.key';
COMMENT ON COLUMN qc_user_settings.value     IS 'Overstyringsverdi. Ingen rad = bruk default. DELETE = tilbakestill.';

COMMIT;
