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
  image_digest       = "sha256:38d90d0d5fa0e56f50f3227900691c5f40e42786ce9155bc905f3cdef72b793f"

  config = {
    AI_PROFILE             = "QUERYCHAT_PROFILE"
    DB_DSN                 = "rdapkipocdb_high"
    DB_USER                = "rdap_chatbot_app_user"
    MAX_ROWS               = "500"
    DBPASS_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
    JWT_SECRET_OCID        = oci_vault_secret.querychat_jwt_secret.id
  }
}

resource "oci_functions_function" "feedback_executor" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "feedback-executor"
  memory_in_mbs      = "256"
  timeout_in_seconds = 60
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/feedback-executor:latest"
  image_digest = "sha256:6ee1a30670ec33f2fecbba88bf43fc1c19bf0a212d0e4379b7ee3055bd85aa69"

  config = {
    DB_DSN                 = "rdapkipocdb_high"
    DB_USER                = "rdap_chatbot_app_user"
    DBPASS_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
    JWT_SECRET_OCID        = oci_vault_secret.querychat_jwt_secret.id}
}

resource "oci_functions_function" "auth_handler" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "auth-handler"
  memory_in_mbs      = "256"
  timeout_in_seconds = 60
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/auth-handler:latest"
  image_digest = "sha256:64108ca76049c2d92c4bb2c0213e7f0472f075a8d91c25162e0f55c74ee747f3"
  
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
  image_digest       = "sha256:1e0b00f10da7345e35870c722bb773e0700fcb09eb030c9ddd42f6f67e4e6818"

  config = {
    DB_DSN                 = "rdapkipocdb_high"
    DB_USER                = "querychat"
    DBPASS_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
    JWT_SECRET_OCID        = oci_vault_secret.querychat_jwt_secret.id
  }
}