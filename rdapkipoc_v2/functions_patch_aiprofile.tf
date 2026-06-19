# ── Legg denne ressursen til på slutten av functions.tf ───────────────────

resource "oci_functions_function" "ai_profile_handler" {
  application_id     = oci_functions_application.rdap_chatbot_application.id
  display_name       = "ai-profile-handler"
  memory_in_mbs      = "256"
  timeout_in_seconds = 60
  image              = "ocir.eu-frankfurt-2.oci.oraclecloud.eu/axpqbvkhoxdj/ai-profile-handler:latest"
  image_digest       = "sha256:0000000000000000000000000000000000000000000000000000000000000000"

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
