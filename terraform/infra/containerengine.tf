data "oci_core_images" "oke_node" {
  compartment_id           = local.compartment_id
  operating_system         = "Oracle Linux"
  operating_system_version = "8"
  shape                    = "VM.Standard3.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

resource "oci_containerengine_cluster" "rdap_chatbot_oke_cluster" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  name           = "rdap-chatbot-oke-cluster"
  type           = "ENHANCED_CLUSTER"

  kubernetes_version = local.kubernetes_version

  cluster_pod_network_options {
    cni_type = "OCI_VCN_IP_NATIVE"
  }

  endpoint_config {
    is_public_ip_enabled = true
    nsg_ids              = []
    subnet_id            = oci_core_subnet.KubernetesAPIendpointSubnet.id
  }

  image_policy_config {
    is_policy_enabled = false
  }

  options {
    add_ons {
      is_kubernetes_dashboard_enabled = false
      is_tiller_enabled               = false
    }

    admission_controller_options {
      is_pod_security_policy_enabled = false
    }

    ip_families = ["IPv4"]

    kubernetes_network_config {
      pods_cidr     = "10.0.1.0/24"
      services_cidr = "10.96.0.0/16"
    }

    persistent_volume_config {
      freeform_tags = {}
    }

    service_lb_config {
      backend_nsg_ids = []
      freeform_tags   = {}
    }

    service_lb_subnet_ids = [oci_core_subnet.loadbalancers_subnet.id]
  }
}

resource "oci_containerengine_node_pool" "rdap_chatbot_oke_node_pool" {
  cluster_id         = oci_containerengine_cluster.rdap_chatbot_oke_cluster.id
  compartment_id     = local.compartment_id
  name               = "rdap-chatbot-oke-node-pool"
  kubernetes_version = local.kubernetes_version
  node_shape         = "VM.Standard3.Flex"

  initial_node_labels {
    key   = "name"
    value = "pool1"
  }

  node_config_details {
    is_pv_encryption_in_transit_enabled = false
    nsg_ids                             = []
    size                                = 2

    node_pool_pod_network_option_details {
      cni_type          = "OCI_VCN_IP_NATIVE"
      max_pods_per_node = 31
      pod_nsg_ids       = []
      pod_subnet_ids    = [oci_core_subnet.workernodes_subnet.id]
    }

    placement_configs {
      availability_domain = data.oci_identity_availability_domain.ads.name
      fault_domains       = ["FAULT-DOMAIN-1"]
      subnet_id           = oci_core_subnet.workernodes_subnet.id
    }
  }

  node_eviction_node_pool_settings {
    eviction_grace_duration              = "PT1H"
    is_force_action_after_grace_duration = false
    is_force_delete_after_grace_duration = false
  }

  node_metadata = {}

  node_shape_config {
    memory_in_gbs = 16
    ocpus         = 2
  }

  node_source_details {
    image_id    = data.oci_core_images.oke_node.images[0].id
    source_type = "IMAGE"
  }
}

data "oci_core_services" "all_services" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}
