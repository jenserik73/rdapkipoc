CREATE TABLE qc_users (
    id            VARCHAR2(32)  DEFAULT RAWTOHEX(SYS_GUID()) PRIMARY KEY,
    email         VARCHAR2(255) NOT NULL,
    display_name  VARCHAR2(100) NOT NULL,
    pw_hash       VARCHAR2(255) NOT NULL,
    active        NUMBER(1)     DEFAULT 1 NOT NULL,
    created_at    TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    last_login    TIMESTAMP,
    CONSTRAINT uq_qc_users_email UNIQUE (email)
);
