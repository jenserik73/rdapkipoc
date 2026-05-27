resource "oci_containerengine_cluster" "rdap_chatbot_oke_cluster" {
  cluster_pod_network_options {
    #Required
    cni_type = "OCI_VCN_IP_NATIVE"
  }
  compartment_id     = local.compartment_id

  endpoint_config { # Public API Server endpoint configuration
    is_public_ip_enabled = "true"
    nsg_ids = [
    ]
    subnet_id            = oci_core_subnet.KubernetesAPIendpointSubnet.id
  }
  image_policy_config {
    is_policy_enabled = "false"
  }
  kubernetes_version = "v1.34.2"
  name               = "rdap-chatbot-oke-cluster"
  options {
    add_ons {
      is_kubernetes_dashboard_enabled = "false"
      is_tiller_enabled               = "false"
    }
    admission_controller_options {
      is_pod_security_policy_enabled = "false"
    }
    ip_families = [
      "IPv4",
    ]
    kubernetes_network_config {
      pods_cidr = "10.0.1.0/24"
      services_cidr = "10.96.0.0/16"
    }
    persistent_volume_config {
      #defined_tags = <<Optional value not found in discovery>>
      freeform_tags = {
      }
    }
    service_lb_config {
      backend_nsg_ids = [
      ]
      #defined_tags = <<Optional value not found in discovery>>
      freeform_tags = {
      }
    }
    service_lb_subnet_ids = [
      oci_core_subnet.loadbalancers_subnet.id
      ]
  }
  type = "ENHANCED_CLUSTER"
  vcn_id             = oci_core_vcn.rdap_chatbot_vcn.id
}

resource "oci_containerengine_node_pool" "rdap_chatbot_oke_node_pool" {
  cluster_id     = oci_containerengine_cluster.rdap_chatbot_oke_cluster.id
  compartment_id = local.compartment_id

  initial_node_labels {
    key   = "name"
    value = "pool1"
  }
  kubernetes_version = "v1.34.2"
  name               = "rdap-chatbot-oke-node-pool"
  network_launch_type = ""

  node_config_details {
    is_pv_encryption_in_transit_enabled = "false"

    node_pool_pod_network_option_details {
      cni_type       = "OCI_VCN_IP_NATIVE"
      max_pods_per_node = "31"
      pod_nsg_ids = [
      ]
      pod_subnet_ids = [
        oci_core_subnet.workernodes_subnet.id
      ]
    }
    nsg_ids = [
    ]
    placement_configs {
      availability_domain = data.oci_identity_availability_domain.ads.name
      fault_domains = [
        "FAULT-DOMAIN-1",
      ]
      subnet_id           = oci_core_subnet.workernodes_subnet.id
    }
    size = 2 # Number of nodes in the node pool
  }
  node_eviction_node_pool_settings {
    eviction_grace_duration              = "PT1H"
    is_force_action_after_grace_duration = "false"
    is_force_delete_after_grace_duration = "false"
  }
  node_metadata = {
  }
  node_shape         = "VM.Standard3.Flex"
  node_shape_config {
    memory_in_gbs = 16
    ocpus         = 2
  }
  node_source_details {

    image_id    = "ocid1.image.oc19.eu-frankfurt-2.aaaaaaaarcspkcorcbd5lapcsyykog63utmpu3so5gmrpaaiycnnkledrdwq"
    source_type = "IMAGE"
  }
}

