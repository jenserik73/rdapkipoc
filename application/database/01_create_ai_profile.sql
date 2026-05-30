-- =============================================================
-- 01_create_ai_profile.sql
-- DBMS_CLOUD_AI profil for QueryChat
-- Skjema: querychat
-- Tabeller: KI_GRUNNLAG_ORACLE_RDAP_BEMANNING
--           KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK
--           KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER
--           KI_GRUNNLAG_ORACLE_RDAP_OKONOMIDATA
-- =============================================================

BEGIN
  DBMS_CLOUD_AI.DROP_PROFILE(profile_name => 'QUERYCHAT_PROFILE_RP');
EXCEPTION
  WHEN OTHERS THEN NULL;
END;
/

BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'QUERYCHAT_PROFILE',
    attributes   => '{
      "provider"           : "oci",
      "credential_name"    : "OCI_GEN_AI_CRED",
      "model"              : "meta.llama-3.3-70b-instruct-fp8-dynamic",
      "oci_compartment_id" : "ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a",
      "region": "eu-frankfurt-2",
      "object_list"        : [
        {"owner": "QUERYCHAT", "name": "KI_GRUNNLAG_ORACLE_RDAP_BEMANNING"},
        {"owner": "QUERYCHAT", "name": "KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK"},
        {"owner": "QUERYCHAT", "name": "KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER"},
        {"owner": "QUERYCHAT", "name": "KI_GRUNNLAG_ORACLE_RDAP_OKONOMIDATA"}
      ],
      "max_tokens"  : 1024,
      "temperature" : 0,
      "enable_sources": "true",
      "annotations": "true",
      "comments": "true",
      "case_sensitive_values":"false",
      "source_language":"no",
      "target_language":"no"
    }'
  );
END;
/

-- Verifiser
SELECT *
FROM   USER_CLOUD_AI_PROFILE_ATTRIBUTES
WHERE  profile_name = 'QUERYCHAT_PROFILE';

/* dette fungere ikke med felles LLM for eu sovereign cloud
BEGIN
  DBMS_CLOUD_AI.CREATE_PROFILE(
    profile_name => 'QUERYCHAT_PROFILE_RP',
    attributes   => '{
      "provider"           : "oci",
      "credential_name"    : "OCI$RESOURCE_PRINCIPAL",
      "model"              : "meta.llama-3.3-70b-instruct-fp8-dynamic",
      "oci_compartment_id" : "ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a",
      "region": "eu-frankfurt-2",
      "object_list"        : [
        {"owner": "QUERYCHAT", "name": "KI_GRUNNLAG_ORACLE_RDAP_BEMANNING"},
        {"owner": "QUERYCHAT", "name": "KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK"},
        {"owner": "QUERYCHAT", "name": "KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER"},
        {"owner": "QUERYCHAT", "name": "KI_GRUNNLAG_ORACLE_RDAP_OKONOMIDATA"}
      ],
      "max_tokens"  : 1024,
      "temperature" : 0,
      "enable_sources": "true",
      "annotations": "true",
      "comments": "true",
      "case_sensitive_values":"false",
      "source_language":"no",
      "target_language":"no"
    }'
  );
END;
/
*/