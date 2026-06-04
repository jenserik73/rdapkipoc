resource oci_bastion_bastion rdapchatbotbastion {
  bastion_type = "STANDARD"
  client_cidr_block_allow_list = [
    "4.210.177.128/32",
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

# Det er en bug med endepunktene for bastion agenten så dette fungerer ikke per dags dato, så derfor er det kommentert ut, og der er en workaround med port forwarding session i stedet, som fungerer fint
# resource "oci_bastion_session" "admin_instance_session" {
#     #Required
#     bastion_id = oci_bastion_bastion.rdapchatbotbastion.id
#     key_details {
#         #Required
#         public_key_content = file("~/.ssh/ssh-key.key.pub")
#     }
#     target_resource_details {
#         #Required
#         session_type = "MANAGED_SSH"

#         target_resource_id = oci_core_instance.admin_instance.id
#         target_resource_operating_system_user_name = "opc"
#         target_resource_port = 22
#         target_resource_private_ip_address = oci_core_instance.admin_instance.create_vnic_details[0].private_ip
#     }

#     #Optional
#     display_name = "admin-instance-session"
#     key_type = "PUB"
#     session_ttl_in_seconds = 10800
# }

resource "oci_bastion_session" "admin_instance_session" {
  bastion_id = oci_bastion_bastion.rdapchatbotbastion.id
  key_details {
    public_key_content = file("~/.ssh/ssh-key.key.pub")
  }
  target_resource_details {
    session_type                       = "PORT_FORWARDING"
    target_resource_private_ip_address = oci_core_instance.admin_instance.create_vnic_details[0].private_ip
    target_resource_port               = 22
  }
  display_name           = "admin-instance-session"
  key_type               = "PUB"
  session_ttl_in_seconds = 10800
}