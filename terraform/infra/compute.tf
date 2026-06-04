resource "oci_core_instance" "admin_instance" {
    display_name = "admin-instance"
    availability_domain = data.oci_identity_availability_domain.ads.name
    compartment_id = local.compartment_id

    #Optional
    agent_config {

        are_all_plugins_disabled = false # denne overstyrer alle plugins, så hvis den er true, så er det ingen plugins der er enabled, og hvis den er false
        is_management_disabled = true
        is_monitoring_disabled = true
        plugins_config {
            desired_state = "ENABLED"
            name          = "Bastion"
        }
    }
    availability_config {
        recovery_action = "RESTORE_INSTANCE"
    }

    create_vnic_details {

        #Optional
        assign_private_dns_record = true
        assign_public_ip = false

        display_name = "admin-instance-vnic"
        hostname_label = "admin-instance"

        subnet_id = oci_core_subnet.functions_subnet.id
    }
    extended_metadata = {
        some_string = "stringA"
        nested_object = "{\"some_string\": \"stringB\", \"object\": {\"some_string\": \"stringC\"}}"
    }
    fault_domain = data.oci_identity_fault_domains.fds.fault_domains[0].name

    launch_options {
        boot_volume_type                    = "PARAVIRTUALIZED"
        firmware                            = "UEFI_64"
        is_consistent_volume_naming_enabled = "true"
        is_pv_encryption_in_transit_enabled = "true"
        network_type                        = "PARAVIRTUALIZED"
        remote_data_volume_type             = "PARAVIRTUALIZED"
    }

    metadata = {
        "ssh_authorized_keys" = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCgpgslDDEsAFgQp7+0n6KfzP4AXLiKReHB34UJj5gc09tzAZ1UYfs9Es1o3fPJQsBUCCLaITDKM4pvxvUDJceaGGVhbs2AQ4bkV0WmDV6/tMzPNfldY2s52izPSLnIiwj+L7cqG+EiuRLQ2PZX1ZMYveBSgTKrLFLFYaFZY4BBGgwiCfDCCdTrWFVBjrJEaTQD0cYOO2Y23QylZGQ9yuzyXXpU6ubfNArSS551yfDzLQVR9u4fWm/r9hiBOoiBv9ZWIuvQ0rn2s6OSK+yO/5qTqC9tO5H4zqc5O6cceYCOzD4Upsx5DvuBIaGfMtRRVUekjKcBHycWols+5GSX7vul ssh-key-2026-06-02"
    }

  platform_config {
    is_measured_boot_enabled             = "false"
    is_memory_encryption_enabled         = "false"
    is_secure_boot_enabled               = "false"
    is_symmetric_multi_threading_enabled = "true"
    is_trusted_platform_module_enabled   = "false"
    type = "AMD_VM"
  }
  security_attributes = {
  }
  shape = "VM.Standard.E5.Flex"
  shape_config {
    memory_in_gbs             = "12"
    ocpus                     = "1"
    vcpus                     = "2"
  }

  source_details {
  source_type             = "image"
  source_id               = data.oci_core_images.ol8.images[0].id
  boot_volume_size_in_gbs = 50
}
}