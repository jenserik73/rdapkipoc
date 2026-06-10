-- Generer hash først:
-- python3 -c "import bcrypt; print(bcrypt.hashpw(b'dittpassord', bcrypt.gensalt()).decode())"

INSERT INTO qc_users (id, email, display_name, pw_hash, active)
VALUES (SYS_GUID(), 'admin@elcarocloud.no', 'Administrator', '$2b$12$lCukYHmwNub7tAS.mqM4WO2FvOC4rMNgLMMnLAhU5Ozslf4C47HLu', 1);

INSERT INTO qc_user_roles (user_id, role_id, granted_at)
SELECT u.id, r.id, SYSTIMESTAMP
FROM qc_users u, qc_roles r
WHERE u.email = 'admin@elcarocloud.no'
AND r.name = 'admin';

COMMIT;