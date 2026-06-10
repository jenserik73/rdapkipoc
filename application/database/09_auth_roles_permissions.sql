CREATE TABLE qc_roles (
    id           RAW(16)       DEFAULT SYS_GUID() PRIMARY KEY,
    name         VARCHAR2(50)  NOT NULL,
    description  VARCHAR2(255),
    CONSTRAINT uq_qc_roles_name UNIQUE (name)
);

CREATE TABLE qc_permissions (
    id            RAW(16)       DEFAULT SYS_GUID() PRIMARY KEY,
    perm_resource VARCHAR2(100) NOT NULL,
    perm_action   VARCHAR2(50)  NOT NULL,
    CONSTRAINT uq_qc_permissions UNIQUE (perm_resource, perm_action)
);

CREATE TABLE qc_role_permissions (
    role_id       RAW(16) NOT NULL,
    permission_id RAW(16) NOT NULL,
    CONSTRAINT pk_qc_role_permissions PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES qc_roles(id),
    CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES qc_permissions(id)
);

CREATE TABLE qc_user_roles (
    user_id    RAW(16)   NOT NULL,
    role_id    RAW(16)   NOT NULL,
    granted_by RAW(16),
    granted_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_qc_user_roles PRIMARY KEY (user_id, role_id),
    CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES qc_users(id),
    CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES qc_roles(id),
    CONSTRAINT fk_ur_granted_by FOREIGN KEY (granted_by) REFERENCES qc_users(id)
);