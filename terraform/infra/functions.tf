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

resource "oci_functions_function" "auth_handler" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "auth-handler"
  memory_in_mbs      = "256"
  timeout_in_seconds = 60
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/auth-handler:latest"
  image_digest       = "sha256:2023215b7b359e22d9b686ebf43b502184003a553def17180809ddc7221694fc"

  config = {
    DB_DSN                    = "rdapkipocdb_high"
    DB_USER                   = "querychat"
    DBPASS_SECRET_OCID        = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID        = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID    = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
    JWT_SECRET_OCID           = oci_vault_secret.querychat_jwt_secret.id
    REFRESH_SECRET_OCID       = oci_vault_secret.querychat_refresh_secret.id
    SMTP_PASSWORD_SECRET_OCID = oci_vault_secret.querychat_smtp_password.id
    SMTP_HOST                 = "smtp.email.eu-frankfurt-2.oci.oraclecloud.com"
    SMTP_PORT                 = "587"
    SMTP_USER                 = "ocid1.user.oc19..aaaaaaaawkogoic3q7guo4huvji3vb5kexemlqthtql3fcc3ickff73og4pq@ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a.9k.com"
    EMAIL_SENDER              = "noreply@elcarocloud.no"
    FRONTEND_URL              = "https://querychat.elcarocloud.no"
  }
}

resource "oci_functions_function" "admin_handler" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "admin-handler"
  memory_in_mbs      = "256"
  timeout_in_seconds = 60
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/admin-handler:latest"
  image_digest       = "sha256:2023215b7b359e22d9b686ebf43b502184003a553def17180809ddc7221694fc"

  config = {
    DB_DSN                 = "rdapkipocdb_high"
    DB_USER                = "querychat"
    DBPASS_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
    JWT_SECRET_OCID        = oci_vault_secret.querychat_jwt_secret.id
  }
}