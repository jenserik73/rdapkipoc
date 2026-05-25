locals {
    config_data = jsondecode(file("${path.module}/../bootstrap/output.json"))
    compartment_id = local.config_data.rdap_chatbotdev_cmp_ocid.value
}

output "compartment_id" {
  value = local.compartment_id
}

