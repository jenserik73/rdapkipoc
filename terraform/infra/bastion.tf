resource "oci_bastion_bastion" "rdapchatbotbastion" {
  bastion_type     = "STANDARD"
  compartment_id   = local.compartment_id
  target_subnet_id = oci_core_subnet.bastion_subnet.id
  name             = "rdapchatbotbastion"

  client_cidr_block_allow_list = ["4.210.177.128/32"]

  dns_proxy_status           = "DISABLED"
  max_session_ttl_in_seconds = 10800
}

# NB: Managed SSH-session (MANAGED_SSH) fungerer ikke per nå pga. en bug med
# Bastion-agent-endepunktene. PORT_FORWARDING brukes som workaround.
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
