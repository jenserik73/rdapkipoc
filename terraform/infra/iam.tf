# ── Dynamic Groups (på tenancy-nivå) ─────────────────────────

resource "oci_identity_dynamic_group" "adb_dynamic_group" {
  compartment_id = module.shared_resources.tenancy_id
  name           = "ADBDynamicGroup"
  description    = "Dynamic group for Autonomous Database"
  matching_rule  = "Any {All {instance.id = 'ocid1.autonomousdatabase.oc19.eu-frankfurt-2.anzxiljrlgam66yanr6c6shcs7afz4kbqkyq3udmzcfexkjqtq52p7yaknea'}}"
}

resource "oci_identity_dynamic_group" "certbot_dynamic_group" {
  compartment_id = module.shared_resources.tenancy_id
  name           = "certbot-dynamic-group"
  description    = "Dynamic Group for certbot-instansen"
  matching_rule  = "instance.id = 'ocid1.instance.oc19.eu-frankfurt-2.anzxiljrlgam66ycczrapys2e73ril7vheytbrkhqk3ap6msiietmrpvoz3a'"
}

resource "oci_identity_dynamic_group" "functions_dynamic_group" {
  compartment_id = module.shared_resources.tenancy_id
  name           = "FunctionsDynamicGroup"
  description    = "Dynamic group for OCI Functions"
  matching_rule  = "All {resource.type = 'fnfunc', resource.compartment.id = 'ocid1.compartment.oc19..aaaaaaaaw7nfek7szdgjrdidzqhkjzx7bw4txy2y3kdydjryavxmei52t5xq'}"
}

# ── Policies på tenancy-nivå ──────────────────────────────────

resource "oci_identity_policy" "oci_generative_ai_policy" {
  compartment_id = module.shared_resources.tenancy_id
  name           = "OCIGenerativeAIPolicy"
  description    = "access OCI Generative AI service from Select AI"
  statements = [
    "allow dynamic-group ADBDynamicGroup to manage generative-ai-family in tenancy",
    "Allow dynamic-group ADBDynamicGroup to read secret-bundle in tenancy"
  ]
}

resource "oci_identity_policy" "rdap_chatbot_function_policy" {
  compartment_id = module.shared_resources.tenancy_id
  name           = "rdap-chatbot-function-policy"
  description    = "Policy for OCI Functions tilgang til secrets og OCIR"
  statements = [
    "Allow service faas to read repos in compartment rdap-chatbot-cmp",
    "Allow dynamic-group FunctionsDynamicGroup to read secret-bundles in compartment rdap-chatbot-cmp",
    "Allow dynamic-group FunctionsDynamicGroup to read vaults in compartment rdap-chatbot-cmp"
  ]
}

# ── Policies på compartment-nivå ─────────────────────────────

resource "oci_identity_policy" "apigw_invoke_functions" {
  compartment_id = local.compartment_id
  name           = "apigw-invoke-functions"
  description    = "Tillater API Gateway å kalle OCI Functions"
  statements = [
    "allow any-user to use functions-family in compartment id ${local.compartment_id} where request.principal.type = 'ApiGateway'"
  ]
}

resource "oci_identity_policy" "certbot_certificates_policy" {
  compartment_id = local.compartment_id
  name           = "certbot-certificates-policy"
  description    = "Tillater certbot-instansen å administrere sertifikater"
  statements = [
    "allow dynamic-group certbot-dynamic-group to manage leaf-certificate-family in compartment id ocid1.compartment.oc19..aaaaaaaaw7nfek7szdgjrdidzqhkjzx7bw4txy2y3kdydjryavxmei52t5xq"
  ]
}