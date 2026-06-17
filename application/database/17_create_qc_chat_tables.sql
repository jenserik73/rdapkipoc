-- Migration 17: Chat sessions og meldinger
-- QueryChat NL2SQL SaaS

CREATE TABLE qc_chat_sessions (
    id          RAW(16)        DEFAULT SYS_GUID() NOT NULL,
    user_id     VARCHAR2(32)   NOT NULL,
    title       VARCHAR2(255)  DEFAULT 'Ny samtale' NOT NULL,
    created_at  TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at  TIMESTAMP      DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_qc_chat_sessions PRIMARY KEY (id),
    CONSTRAINT fk_chat_sessions_user
        FOREIGN KEY (user_id) REFERENCES qc_users(id) ON DELETE CASCADE
);

CREATE INDEX idx_chat_sessions_user_updated
    ON qc_chat_sessions (user_id, updated_at DESC);

COMMENT ON TABLE  qc_chat_sessions            IS 'Chat-samtaler per bruker';
COMMENT ON COLUMN qc_chat_sessions.id         IS 'UUID (RAW 16) primærnøkkel';
COMMENT ON COLUMN qc_chat_sessions.user_id    IS 'FK til qc_users.id (VARCHAR2 hex)';
COMMENT ON COLUMN qc_chat_sessions.title      IS 'Vises i sidebar; auto-settes til første spørsmål (maks 80 tegn)';
COMMENT ON COLUMN qc_chat_sessions.updated_at IS 'Oppdateres ved ny melding – brukes for sortering i sidebar';

-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE qc_chat_messages (
    id          RAW(16)       DEFAULT SYS_GUID() NOT NULL,
    session_id  RAW(16)       NOT NULL,
    role        VARCHAR2(16)  NOT NULL,
    content     CLOB          NOT NULL,
    created_at  TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_qc_chat_messages PRIMARY KEY (id),
    CONSTRAINT fk_chat_msg_session
        FOREIGN KEY (session_id) REFERENCES qc_chat_sessions(id) ON DELETE CASCADE,
    CONSTRAINT chk_chat_msg_role
        CHECK (role IN ('user', 'assistant', 'error'))
);

CREATE INDEX idx_chat_messages_session_created
    ON qc_chat_messages (session_id, created_at ASC);

COMMENT ON TABLE  qc_chat_messages            IS 'Enkeltmeldinger i en chat-samtale';
COMMENT ON COLUMN qc_chat_messages.role       IS 'user | assistant | error';
COMMENT ON COLUMN qc_chat_messages.content    IS 'Meldingens innhold – CLOB for lange SQL-resultater';

COMMIT;
