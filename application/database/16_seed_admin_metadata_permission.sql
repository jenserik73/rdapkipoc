-- =====================================================================
-- Migrasjon: admin:metadata permission
--
-- Legger til en ny permission (perm_resource='admin', perm_action='metadata'
-- -> "admin:metadata" i JWT-payloaden, jf. _require_permission i
-- admin-handler/func.py og formatet perm_resource || ':' || perm_action
-- fra 11_seed_roles_permissions.sql), og gir den til 'admin'-rollen.
--
-- id genereres av DEFAULT RAWTOHEX(SYS_GUID()) paa qc_permissions.
-- Idempotent: UNIQUE(perm_resource, perm_action) + WHERE NOT EXISTS.
-- =====================================================================

-- 1. Opprett permission hvis den ikke finnes
INSERT INTO qc_permissions (perm_resource, perm_action)
SELECT 'admin', 'metadata'
FROM dual
WHERE NOT EXISTS (
  SELECT 1 FROM qc_permissions
  WHERE perm_resource = 'admin' AND perm_action = 'metadata'
);

-- 2. Tildel til 'admin'-rollen
INSERT INTO qc_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM qc_roles r, qc_permissions p
WHERE r.name = 'admin'
AND p.perm_resource = 'admin' AND p.perm_action = 'metadata'
AND NOT EXISTS (
  SELECT 1 FROM qc_role_permissions rp
  WHERE rp.role_id = r.id AND rp.permission_id = p.id
);

COMMIT;

-- =====================================================================
-- Verifiser:
-- SELECT r.name, p.perm_resource || ':' || p.perm_action AS permission
-- FROM qc_role_permissions rp
-- JOIN qc_roles r ON rp.role_id = r.id
-- JOIN qc_permissions p ON rp.permission_id = p.id
-- WHERE p.perm_resource = 'admin' AND p.perm_action = 'metadata';
--
-- Rollback:
-- DELETE FROM qc_role_permissions WHERE permission_id =
--   (SELECT id FROM qc_permissions WHERE perm_resource='admin' AND perm_action='metadata');
-- DELETE FROM qc_permissions WHERE perm_resource='admin' AND perm_action='metadata';
-- =====================================================================
