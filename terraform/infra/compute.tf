resource "oci_core_instance" "admin_instance" {
  display_name        = "admin-instance"
  availability_domain = data.oci_identity_availability_domain.ads.name
  compartment_id      = local.compartment_id

  agent_config {
    # are_all_plugins_disabled overrider alle plugins; sett til false for å
    # kunne aktivere enkeltplugins som Bastion nedenfor.
    are_all_plugins_disabled = false
    is_management_disabled   = true
    is_monitoring_disabled   = true

    plugins_config {
      desired_state = "ENABLED"
      name          = "Bastion"
    }
  }

  availability_config {
    recovery_action = "RESTORE_INSTANCE"
  }

  create_vnic_details {
    assign_private_dns_record = true
    assign_public_ip          = false
    display_name              = "admin-instance-vnic"
    hostname_label            = "admin-instance"
    subnet_id                 = oci_core_subnet.functions_subnet.id
  }

  fault_domain = data.oci_identity_fault_domains.fds.fault_domains[0].name

  launch_options {
    boot_volume_type                    = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    is_consistent_volume_naming_enabled = true
    is_pv_encryption_in_transit_enabled = true
    network_type                        = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
  }

  metadata = {
    "ssh_authorized_keys" = local.admin_instance_ssh_public_key
  }

  platform_config {
    is_measured_boot_enabled             = false
    is_memory_encryption_enabled         = false
    is_secure_boot_enabled               = false
    is_symmetric_multi_threading_enabled = true
    is_trusted_platform_module_enabled   = false
    type                                 = "AMD_VM"
  }

  shape = "VM.Standard.E5.Flex"

  shape_config {
    memory_in_gbs = 12
    ocpus         = 1
    vcpus         = 2
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ol8.images[0].id
    boot_volume_size_in_gbs = 50
  }
}
