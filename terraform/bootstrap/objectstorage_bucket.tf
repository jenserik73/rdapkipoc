resource "oci_objectstorage_bucket" "rdap_chatbot_terraform_state" {
  compartment_id = oci_identity_compartment.rdap_chatbotdev_cmp.id
  namespace      = data.oci_objectstorage_namespace.ns.namespace
  name           = module.shared_resources.bucket_name
  access_type    = "NoPublicAccess"

  versioning = "Enabled"

  freeform_tags = {
    "ManagedBy" = "Terraform"
    "Purpose"   = "RDAPChatbotTerraformState"
  }
}

data "oci_objectstorage_namespace" "ns" {
  compartment_id = module.shared_resources.tenancy_id
}

output "bucket_name" {
  value = oci_objectstorage_bucket.rdap_chatbot_terraform_state.name
}

output "namespace" {
  value = data.oci_objectstorage_namespace.ns.namespace
}