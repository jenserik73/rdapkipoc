
begin
  dbms_cloud_ai.drop_profile(
    profile_name => 'OCI_GEN_AI_PROFILE'
  );
end;
/

begin 
    dbms_cloud_ai.create_profile(
    'OCI_GEN_AI_PROFILE',
    '{"provider": "oci",
    "credential_name": "oci_gen_ai_cred",
    "oci_compartment_id": "ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a",
    "region": "eu-frankfurt-2",
    "model": "meta.llama-3.3-70b-instruct-fp8-dynamic",
    "object_list": [{"owner": "RDAPKIPOC", "name": "KI_GRUNNLAG_ORACLE_RDAP_BEMANNING"},
                    {"owner": "RDAPKIPOC", "name": "KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK"}
                    {"owner": "RDAPKIPOC", "name": "KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER"},
                    {"owner": "RDAPKIPOC", "name": "KI_GRUNNLAG_ORACLE_RDAP_OKONOMIDATA"}],
    "enable_sources": true
    }');
end;
/

begin
    dbms_cloud_ai.create_profile( 
        'OCI_GEN_AI_BEMANNING_PROFILE',
        '{"provider": "oci",
        "credential_name": "OCI_GEN_AI_CRED",
        "oci_compartment_id": "ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a",
        "region": "eu-frankfurt-2",
        "model": "meta.llama-3.3-70b-instruct-fp8-dynamic",
        "object_list": [{"owner": "RDAPKIPOC", "name": "KI_GRUNNLAG_ORACLE_RDAP_BEMANNING"},
        "enable_sources": true
    }');
end; 
/

begin
    dbms_cloud_ai.create_profile( 
        'OCI_GEN_AI_HR_PROFILE',
        '{"provider": "oci",
        "credential_name": "OCI_GEN_AI_CRED",
        "oci_compartment_id": "ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a",
        "region": "eu-frankfurt-2",
        "model": "meta.llama-3.3-70b-instruct-fp8-dynamic",
        "object_list": [{"owner": "RDAPKIPOC", "name": "KI_GRUNNLAG_ORACLE_RDAP_HR_MNDVERK"},
        "enable_sources": true
    }');
end; 
/

begin
    dbms_cloud_ai.create_profile( 
        'OCI_GEN_AI_LIGGETIMER_PROFILE',
        '{"provider": "oci",
        "credential_name": "OCI_GEN_AI_CRED",
        "oci_compartment_id": "ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a",
        "region": "eu-frankfurt-2",
        "model": "meta.llama-3.3-70b-instruct-fp8-dynamic",
        "object_list": [{"owner": "RDAPKIPOC", "name": "KI_GRUNNLAG_ORACLE_RDAP_LIGGETIMER_MNDVERK"},
        "enable_sources": true
    }');
end; 
/

begin
    dbms_cloud_ai.create_profile( 
        'OCI_GEN_AI_OKONOMIDATA_PROFILE',
        '{"provider": "oci",
        "credential_name": "OCI_GEN_AI_CRED",
        "oci_compartment_id": "ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a",
        "region": "eu-frankfurt-2",
        "model": "meta.llama-3.3-70b-instruct-fp8-dynamic",
        "object_list": [{"owner": "RDAPKIPOC", "name": "KI_GRUNNLAG_ORACLE_RDAP_OKONOMIDATA"},
        "enable_sources": true
    }');
end; 
/

select distinct AAR
from bemanning;

begin
    DBMS_CLOUD_AI.set_profile(profile_name => 'OCI_GEN_AI_PROFILE');
end;
/

select ai showsql lag en oversikt over totalt antall årsverk per år for leger i perioden 2015 til 2025;

select ai narrate predict the total overtime hours for doctors in 2027 based on the trend from 2015 to 2025;
