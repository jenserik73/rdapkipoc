resource "oci_identity_compartment" "rdap_chatbotdev_cmp" {
    #Required
    compartment_id = module.shared_resources.tenancy_id
    description = module.shared_resources.compartment_description
    name = module.shared_resources.compartment_name
}

output "rdap_chatbotdev_cmp_ocid" {
  value = oci_identity_compartment.rdap_chatbotdev_cmp.id
}

output "rdap_chatbotdev_cmp_name" {
  value = oci_identity_compartment.rdap_chatbotdev_cmp.name
}