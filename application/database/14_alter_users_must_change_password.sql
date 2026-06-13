-- ============================================================
-- QueryChat – Legg til must_change_password-kolonne
-- Kjøres én gang som querychat-bruker i ADB
-- Kjørt: 2026-06-13
-- ============================================================

ALTER TABLE qc_users ADD must_change_password NUMBER(1) DEFAULT 0 NOT NULL;

-- Verifiser
SELECT column_name, data_type, data_default, nullable
FROM user_tab_columns
WHERE table_name = 'QC_USERS'
AND column_name = 'MUST_CHANGE_PASSWORD';
