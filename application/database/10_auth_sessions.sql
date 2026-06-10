CREATE TABLE qc_refresh_tokens (
    token        VARCHAR2(64)  NOT NULL,
    user_id      RAW(16)       NOT NULL,
    device_hint  VARCHAR2(255),
    created_at   TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    expires_at   TIMESTAMP     NOT NULL,
    revoked      NUMBER(1)     DEFAULT 0 NOT NULL,
    CONSTRAINT pk_qc_refresh_tokens PRIMARY KEY (token),
    CONSTRAINT fk_rt_user FOREIGN KEY (user_id) REFERENCES qc_users(id)
);

CREATE TABLE qc_password_resets (
    token      VARCHAR2(64)  NOT NULL,
    user_id    RAW(16)       NOT NULL,
    created_at TIMESTAMP     DEFAULT SYSTIMESTAMP NOT NULL,
    expires_at TIMESTAMP     NOT NULL,
    used       NUMBER(1)     DEFAULT 0 NOT NULL,
    CONSTRAINT pk_qc_password_resets PRIMARY KEY (token),
    CONSTRAINT fk_pr_user FOREIGN KEY (user_id) REFERENCES qc_users(id)
);

CREATE INDEX idx_refresh_tokens_user    ON qc_refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires ON qc_refresh_tokens(expires_at);
CREATE INDEX idx_password_resets_user   ON qc_password_resets(user_id);