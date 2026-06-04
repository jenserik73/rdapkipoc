resource oci_bastion_bastion rdapchatbotbastion {
  bastion_type = "STANDARD"
  client_cidr_block_allow_list = [
    "4.210.177.134/32",
  ]
  compartment_id = local.compartment_id

  dns_proxy_status = "DISABLED"

  max_session_ttl_in_seconds = "10800"
  name                       = "rdapchatbotbastion"
  #phone_book_entry = <<Optional value not found in discovery>>
  security_attributes = {
  }
  static_jump_host_ip_addresses = [
  ]
  target_subnet_id = oci_core_subnet.bastion_subnet.id
}

