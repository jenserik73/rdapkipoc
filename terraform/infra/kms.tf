resource "oci_kms_vault" "rdap_chatbot_vault" {
  compartment_id = local.compartment_id
  display_name   = "rdap-chatbot-vault"
  vault_type     = "DEFAULT"
}

resource "oci_kms_key" "rdap_chatbot_master_encryption_key" {
  compartment_id = local.compartment_id
  display_name   = "rdap-chatbot-master-encryption-key"

  key_shape {
    algorithm = "AES"
    length    = 32
  }

  management_endpoint      = oci_kms_vault.rdap_chatbot_vault.management_endpoint
  is_auto_rotation_enabled = false
  protection_mode          = "SOFTWARE"
}

resource "oci_vault_secret" "rdapkipocdb_wallet" {
  compartment_id = local.compartment_id
  description    = "Oracle Wallet for Autonomous Database used by RDAP Chatbot"
  key_id         = oci_kms_key.rdap_chatbot_master_encryption_key.id
  secret_name    = "rdapkipocdb-wallet"
  vault_id       = oci_kms_vault.rdap_chatbot_vault.id

  secret_content {
    content_type = "BASE64"
    content      = filebase64(var.wallet_file_path)
  }
}

resource "oci_vault_secret" "rdapkipocdb_wallet_password" {
  compartment_id = local.compartment_id
  description    = "Password for Oracle Wallet used by RDAP Chatbot"
  key_id         = oci_kms_key.rdap_chatbot_master_encryption_key.id
  secret_name    = "rdapkipocdb-wallet-password"
  vault_id       = oci_kms_vault.rdap_chatbot_vault.id

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.RDAPKIPOCDB_WALLET_PASSWORD)
  }
}

resource "oci_vault_secret" "rdapkipocdb_password" {
  compartment_id = local.compartment_id
  description    = "Password for Oracle Autonomous Database user used by RDAP Chatbot"
  key_id         = oci_kms_key.rdap_chatbot_master_encryption_key.id
  secret_name    = "rdapkipocdb-password"
  vault_id       = oci_kms_vault.rdap_chatbot_vault.id

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.RDAPKIPOCDB_PASSWORD)
  }
}

resource "oci_vault_secret" "querychat_jwt_secret" {
  compartment_id = local.compartment_id
  description    = "Secret for signing JWT access tokens in QueryChat"
  key_id         = oci_kms_key.rdap_chatbot_master_encryption_key.id
  secret_name    = "querychat-jwt-secret"
  vault_id       = oci_kms_vault.rdap_chatbot_vault.id

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.QUERYCHAT_JWT_SECRET)
  }
}

resource "oci_vault_secret" "querychat_refresh_secret" {
  compartment_id = local.compartment_id
  description    = "Secret for signing refresh tokens in QueryChat"
  key_id         = oci_kms_key.rdap_chatbot_master_encryption_key.id
  secret_name    = "querychat-refresh-secret"
  vault_id       = oci_kms_vault.rdap_chatbot_vault.id

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.QUERYCHAT_REFRESH_SECRET)
  }
}

resource "oci_vault_secret" "querychat_smtp_password" {
  compartment_id = local.compartment_id
  description    = "SMTP password for OCI Email Delivery used by QueryChat auth"
  key_id         = oci_kms_key.rdap_chatbot_master_encryption_key.id
  secret_name    = "querychat-smtp-password"
  vault_id       = oci_kms_vault.rdap_chatbot_vault.id

  secret_content {
    content_type = "BASE64"
    content      = base64encode(var.QUERYCHAT_SMTP_PASSWORD)
  }
}