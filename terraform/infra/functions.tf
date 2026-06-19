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
  image_digest       = "sha256:94dae5d18929ac0a6b254888f68e98c8fc6f88eabfe11bfc5515281db71ce450"

  config = {
    AI_PROFILE             = "QUERYCHAT_PROFILE"
    DB_DSN                 = "rdapkipocdb_high"
    DB_USER                = "rdap_chatbot_app_user"
    MAX_ROWS               = "500"
    DBPASS_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
    JWT_SECRET_OCID        = oci_vault_secret.querychat_jwt_secret.id
    LOG_LEVEL              = "INFO"   # Sett til "DEBUG" ved feilsøking
  }
}

resource "oci_functions_function" "feedback_executor" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "feedback-executor"
  memory_in_mbs      = "256"
  timeout_in_seconds = 60
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/feedback-executor:latest"
  image_digest = "sha256:dad10bb3a806bf4a948e17604d743ce22a0d6813df7dd1ec88332634b09a52d5"

  config = {
    DB_DSN                 = "rdapkipocdb_high"
    DB_USER                = "rdap_chatbot_app_user"
    DBPASS_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
    JWT_SECRET_OCID        = oci_vault_secret.querychat_jwt_secret.id
    LOG_LEVEL              = "INFO"   # Sett til "DEBUG" ved feilsøking
    }
}

resource "oci_functions_function" "auth_handler" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "auth-handler"
  memory_in_mbs      = "256"
  timeout_in_seconds = 60
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/auth-handler:latest"
  image_digest = "sha256:f4d78aa73245c66d01d2fb63ed965e2fc801fbca47dab395a6cf7390b86b9662"
  
  config = {
    DB_DSN                    = "rdapkipocdb_high"
    DB_USER                   = "querychat"
    DBPASS_SECRET_OCID        = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID        = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID    = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
    JWT_SECRET_OCID           = oci_vault_secret.querychat_jwt_secret.id
    REFRESH_SECRET_OCID       = oci_vault_secret.querychat_refresh_secret.id
    SMTP_PASSWORD_SECRET_OCID = oci_vault_secret.querychat_smtp_password.id
    SMTP_HOST                 = "smtp.email.eu-frankfurt-2.oci.oraclecloud.eu"
    SMTP_PORT                 = "587"
    SMTP_USER                 = "ocid1.user.oc19..aaaaaaaawkogoic3q7guo4huvji3vb5kexemlqthtql3fcc3ickff73og4pq@ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a.9k.com"
    EMAIL_SENDER              = "noreply@elcarocloud.no"
    FRONTEND_URL              = "https://querychat.elcarocloud.no"
    LOG_LEVEL                 = "INFO"   # Sett til "DEBUG" ved feilsøking
  }
}

resource "oci_functions_function" "admin_handler" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "admin-handler"
  memory_in_mbs      = "256"
  timeout_in_seconds = 60
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/admin-handler:latest"
  image_digest       = "sha256:8b5175d5f705b697c2ead324c32937dee74725d9d30d1c5cf16797a6e620f9e1"

  config = {
    DB_DSN                 = "rdapkipocdb_high"
    DB_USER                = "querychat"
    DBPASS_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
    JWT_SECRET_OCID        = oci_vault_secret.querychat_jwt_secret.id
    LOG_LEVEL              = "INFO"   # Sett til "DEBUG" ved feilsøking
    SMTP_PASSWORD_SECRET_OCID = oci_vault_secret.querychat_smtp_password.id
    SMTP_HOST                 = "smtp.email.eu-frankfurt-2.oci.oraclecloud.eu"
    SMTP_PORT                 = "587"
    SMTP_USER                 = "ocid1.user.oc19..aaaaaaaawkogoic3q7guo4huvji3vb5kexemlqthtql3fcc3ickff73og4pq@ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a.9k.com"
    EMAIL_SENDER              = "noreply@elcarocloud.no"
    FRONTEND_URL              = "https://querychat.elcarocloud.no"
  }
}

resource "oci_functions_function" "chat_handler" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "chat-handler"
  memory_in_mbs      = "256"
  timeout_in_seconds = 60
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/chat-handler:latest"
  image_digest       = "sha256:4e7b036e1331b293ec3baa3168b8c17f219a6c5224136a6cc45e313dc0b9999b"

  config = {
    DB_DSN                 = "rdapkipocdb_high"
    DB_USER                = "querychat"
    DBPASS_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
    JWT_SECRET_OCID        = oci_vault_secret.querychat_jwt_secret.id
    LOG_LEVEL              = "INFO"
  }
}

resource "oci_functions_function" "profile_handler" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "profile-handler"
  memory_in_mbs      = "256"
  timeout_in_seconds = 60
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/profile-handler:latest"
  image_digest       = "sha256:78a3853a3dfbc851f6ecf32977dd92ac5bbe438ca5d674ffe4d7a35b38b73426"

  config = {
    DB_DSN                 = "rdapkipocdb_high"
    DB_USER                = "querychat"
    DBPASS_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
    JWT_SECRET_OCID        = oci_vault_secret.querychat_jwt_secret.id
    LOG_LEVEL              = "INFO"
  }
}

resource "oci_functions_function" "ai_profile_handler" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "ai-profile-handler"
  memory_in_mbs      = "256"
  timeout_in_seconds = 60
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/ai-profile-handler:latest"
  image_digest       = "sha256:2436de9fd8032371a2f4b4515d191d8eb6970136331d93fb5926eb708eed58e4"

  config = {
    DB_DSN                 = "rdapkipocdb_high"
    DB_USER                = "querychat"
    DBPASS_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yauk7ukm6zwo65vuygwr6pay4ajv3cyg3vbvixygqzfovq"
    WALLET_SECRET_OCID     = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yaxjtwi247netyi2vuamlrspftpykh2t37miwi2m4yll2q"
    WALLETPASS_SECRET_OCID = "ocid1.vaultsecret.oc19.eu-frankfurt-2.amaaaaaalgam66yac4hzlxmaenlhwgv4lujti7jbtudp7xzexjgi6elqpmda"
    JWT_SECRET_OCID        = oci_vault_secret.querychat_jwt_secret.id
    LOG_LEVEL              = "INFO"
  }
}
