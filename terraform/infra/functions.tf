resource "oci_functions_application" "rdap_chatbot_application" {
  compartment_id = local.compartment_id
  display_name   = "rdap-chatbot-application"
  shape          = "GENERIC_X86"

  subnet_ids = [oci_core_subnet.functions_subnet.id]

  image_policy_config {
    is_policy_enabled = false
  }

  network_security_group_ids = []
}

resource "oci_functions_function" "sql_executor" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "sql-executor"
  memory_in_mbs      = "256"
  timeout_in_seconds = 300
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/sql-executor:latest"
  image_digest       = "sha256:b74d9ba921a7f9afd30861392f3a2489782e3e97c3492af371220514ee36c70c"

  config = {
    AI_PROFILE             = "QUERYCHAT_PROFILE"
    DB_DSN                 = "rdapkipocdb_high"
    DB_USER                = "rdap_chatbot_app_user"
    MAX_ROWS               = "500"
    DBPASS_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
  }
}

resource "oci_functions_function" "feedback_executor" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "feedback-executor"
  memory_in_mbs      = "256"
  timeout_in_seconds = 60
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/feedback-executor:latest"
  image_digest       = "sha256:41b96642eaa786877507053265fdf1b0dbccbe42c7e7014f2aba034f434ca217"

  config = {
    DB_DSN                 = "rdapkipocdb_high"
    DB_USER                = "rdap_chatbot_app_user"
    DBPASS_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
  }
}
