INSERT INTO qc_roles (id, name, description) VALUES
    (SYS_GUID(), 'admin', 'Full tilgang til alle funksjoner og administrasjon');
INSERT INTO qc_roles (id, name, description) VALUES
    (SYS_GUID(), 'analyst', 'Kan kjøre spørringer og se resultater');
INSERT INTO qc_roles (id, name, description) VALUES
    (SYS_GUID(), 'viewer', 'Kan kun se resultater, ikke kjøre nye spørringer');

INSERT INTO qc_permissions (id, perm_resource, perm_action) VALUES (SYS_GUID(), 'query', 'execute');
INSERT INTO qc_permissions (id, perm_resource, perm_action) VALUES (SYS_GUID(), 'query', 'read');
INSERT INTO qc_permissions (id, perm_resource, perm_action) VALUES (SYS_GUID(), 'feedback', 'write');
INSERT INTO qc_permissions (id, perm_resource, perm_action) VALUES (SYS_GUID(), 'admin', 'users');
INSERT INTO qc_permissions (id, perm_resource, perm_action) VALUES (SYS_GUID(), 'admin', 'roles');

-- admin får alle rettigheter
INSERT INTO qc_role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM qc_roles r, qc_permissions p
WHERE r.name = 'admin';

-- analyst får query:execute, query:read, feedback:write
INSERT INTO qc_role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM qc_roles r, qc_permissions p
WHERE r.name = 'analyst'
AND p.perm_resource || ':' || p.perm_action IN ('query:execute', 'query:read', 'feedback:write');

-- viewer får query:read
INSERT INTO qc_role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM qc_roles r, qc_permissions p
WHERE r.name = 'viewer'
AND p.perm_resource || ':' || p.perm_action = 'query:read';

COMMIT;