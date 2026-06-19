-- Migration 19: Seed innstillingsdefaults + admin:profiles permission
-- QueryChat NL2SQL SaaS

-- ── Standardinnstillinger ─────────────────────────────────────────────────────
INSERT INTO qc_settings_defaults (key, value, description, category) VALUES
    ('ui.theme',            'light', 'Fargetema: light | dark | system',               'ui');
INSERT INTO qc_settings_defaults (key, value, description, category) VALUES
    ('ui.language',         'nb',    'Grensesnittspråk: nb | en',                      'ui');
INSERT INTO qc_settings_defaults (key, value, description, category) VALUES
    ('ui.results_per_page', '25',    'Antall rader vist i SQL-resultat-tabell',        'ui');
INSERT INTO qc_settings_defaults (key, value, description, category) VALUES
    ('query.auto_title',    'true',  'Sett chat-tittel automatisk fra første spørsmål','query');
INSERT INTO qc_settings_defaults (key, value, description, category) VALUES
    ('query.show_sql',      'true',  'Vis generert SQL under svaret',                  'query');
INSERT INTO qc_settings_defaults (key, value, description, category) VALUES
    ('query.max_rows',      '500',   'Maks antall rader returnert fra ADB',            'query');
INSERT INTO qc_settings_defaults (key, value, description, category) VALUES
    ('notifications.email', 'false', 'Send e-postvarsler ved feil',                   'notifications');

-- ── admin:profiles permission ─────────────────────────────────────────────────
-- qc_permissions har kolonnene: id, perm_resource, perm_action (IKKE name/description)
DECLARE
    v_count NUMBER;
    v_id    VARCHAR2(32);
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM qc_permissions
    WHERE perm_resource = 'admin' AND perm_action = 'profiles';

    IF v_count = 0 THEN
        v_id := UPPER(RAWTOHEX(SYS_GUID()));
        INSERT INTO qc_permissions (id, perm_resource, perm_action)
        VALUES (v_id, 'admin', 'profiles');
        DBMS_OUTPUT.PUT_LINE('Opprettet admin:profiles med id: ' || v_id);
    ELSE
        DBMS_OUTPUT.PUT_LINE('admin:profiles finnes allerede – hopper over');
    END IF;
END;
/

-- Gi admin:profiles til alle roller som allerede har admin:users
-- (via qc_role_permissions)
DECLARE
    v_profiles_id qc_permissions.id%TYPE;
    v_users_id    qc_permissions.id%TYPE;
BEGIN
    BEGIN
        SELECT id INTO v_profiles_id
        FROM qc_permissions WHERE perm_resource = 'admin' AND perm_action = 'profiles';

        SELECT id INTO v_users_id
        FROM qc_permissions WHERE perm_resource = 'admin' AND perm_action = 'users';
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('En av permissionene finnes ikke – hopper over role-propagering');
            RETURN;
    END;

    FOR r IN (
        SELECT DISTINCT role_id
        FROM qc_role_permissions
        WHERE permission_id = v_users_id
    ) LOOP
        DECLARE v_exists NUMBER; BEGIN
            SELECT COUNT(*) INTO v_exists
            FROM qc_role_permissions
            WHERE role_id = r.role_id AND permission_id = v_profiles_id;
            IF v_exists = 0 THEN
                INSERT INTO qc_role_permissions (role_id, permission_id)
                VALUES (r.role_id, v_profiles_id);
                DBMS_OUTPUT.PUT_LINE('Lagt til admin:profiles for rolle: ' || r.role_id);
            END IF;
        END;
    END LOOP;
END;
/

COMMIT;