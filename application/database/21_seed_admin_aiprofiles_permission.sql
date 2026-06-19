-- Migration 21: Seed eksisterende QUERYCHAT_PROFILE + admin:aiprofiles permission
-- QueryChat NL2SQL SaaS

-- ── Registrer eksisterende QUERYCHAT_PROFILE i katalogen ──────────────────────
-- Verdiene under er hentet fra application/database/setup/oci_gen_ai_profile.sql.
-- Denne profilen er allerede opprettet i ADB via DBMS_CLOUD_AI.CREATE_PROFILE,
-- så vi setter sync_status = 'SYNCED' direkte (ingen DDL kjøres her).
DECLARE
    v_count NUMBER;
    v_id    VARCHAR2(32);
BEGIN
    SELECT COUNT(*) INTO v_count FROM qc_ai_profiles WHERE profile_name = 'QUERYCHAT_PROFILE';

    IF v_count = 0 THEN
        v_id := UPPER(RAWTOHEX(SYS_GUID()));
        INSERT INTO qc_ai_profiles (
            id, profile_name, display_name, description,
            provider, credential_name, model,
            oci_compartment_id, region,
            max_tokens, temperature,
            enable_sources, annotations, comments, case_sensitive_values,
            source_language, target_language,
            object_list, is_active, is_default, sync_status
        ) VALUES (
            v_id, 'QUERYCHAT_PROFILE', 'Standard (Llama 3.3 70B)',
            'Opprinnelig profil satt opp i setup.sql. Llama 3.3 70B via OCI Generative AI.',
            'oci', 'OCI_GEN_AI_CRED', 'meta.llama-3.3-70b-instruct-fp8-dynamic',
            'ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a',
            'eu-frankfurt-2',
            1024, 0,
            'Y', 'Y', 'Y', 'N',
            'no', 'no',
            '[
                {"owner":"QUERYCHAT","name":"KI_GRUNNLAG_ORACLE_RDAP_BEMANNING"},
                {"owner":"QUERYCHAT","name":"KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK"},
                {"owner":"QUERYCHAT","name":"KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER"},
                {"owner":"QUERYCHAT","name":"KI_GRUNNLAG_ORACLE_RDAP_OKONOMIDATA"}
            ]',
            'Y', 'Y', 'SYNCED'
        );
        DBMS_OUTPUT.PUT_LINE('Registrert QUERYCHAT_PROFILE med id: ' || v_id);
    ELSE
        DBMS_OUTPUT.PUT_LINE('QUERYCHAT_PROFILE finnes allerede i katalogen – hopper over');
    END IF;
END;
/

-- Gi alle eksisterende brukere tilgang til standardprofilen
INSERT INTO qc_user_ai_profiles (user_id, ai_profile_id, granted_by)
SELECT u.id, p.id, NULL
FROM   qc_users u
CROSS  JOIN qc_ai_profiles p
WHERE  p.profile_name = 'QUERYCHAT_PROFILE'
AND    NOT EXISTS (
    SELECT 1 FROM qc_user_ai_profiles up
    WHERE up.user_id = u.id AND up.ai_profile_id = p.id
);

-- Sett standardprofilen som aktiv for alle brukere som ikke har valgt noe ennå
INSERT INTO qc_user_active_ai_profile (user_id, ai_profile_id)
SELECT u.id, p.id
FROM   qc_users u
CROSS  JOIN qc_ai_profiles p
WHERE  p.profile_name = 'QUERYCHAT_PROFILE'
AND    NOT EXISTS (
    SELECT 1 FROM qc_user_active_ai_profile a WHERE a.user_id = u.id
);

-- ── admin:aiprofiles permission ────────────────────────────────────────────────
DECLARE
    v_count NUMBER;
    v_id    VARCHAR2(32);
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM qc_permissions
    WHERE perm_resource = 'admin' AND perm_action = 'aiprofiles';

    IF v_count = 0 THEN
        v_id := UPPER(RAWTOHEX(SYS_GUID()));
        INSERT INTO qc_permissions (id, perm_resource, perm_action)
        VALUES (v_id, 'admin', 'aiprofiles');
        DBMS_OUTPUT.PUT_LINE('Opprettet admin:aiprofiles med id: ' || v_id);
    ELSE
        DBMS_OUTPUT.PUT_LINE('admin:aiprofiles finnes allerede – hopper over');
    END IF;
END;
/

-- Gi admin:aiprofiles til alle roller som allerede har admin:users
DECLARE
    v_aiprofiles_id qc_permissions.id%TYPE;
    v_users_id      qc_permissions.id%TYPE;
BEGIN
    BEGIN
        SELECT id INTO v_aiprofiles_id
        FROM qc_permissions WHERE perm_resource = 'admin' AND perm_action = 'aiprofiles';

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
            WHERE role_id = r.role_id AND permission_id = v_aiprofiles_id;
            IF v_exists = 0 THEN
                INSERT INTO qc_role_permissions (role_id, permission_id)
                VALUES (r.role_id, v_aiprofiles_id);
                DBMS_OUTPUT.PUT_LINE('Lagt til admin:aiprofiles for rolle: ' || r.role_id);
            END IF;
        END;
    END LOOP;
END;
/

COMMIT;
