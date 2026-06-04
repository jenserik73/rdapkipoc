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
