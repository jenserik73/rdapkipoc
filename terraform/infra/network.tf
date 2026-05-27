data "oci_core_services" "all_services" {}

locals {
  str_service = [
    for s in data.oci_core_services.all_services.services :
    s if s.name == "All STR Services In Oracle Services Network"
  ][0]
}

resource "oci_core_vcn" "rdap_chatbot_vcn" {
    #Required
    compartment_id = local.compartment_id

    #Optional
    cidr_blocks = var.vcn_cidr_blocks
    display_name = var.vcn_display_name
    dns_label = var.vcn_dns_label
    ipv6private_cidr_blocks = var.vcn_ipv6private_cidr_blocks
    is_ipv6enabled = var.vcn_is_ipv6enabled
    security_attributes = var.vcn_security_attributes
}

output "vcn_id" {
    value = oci_core_vcn.rdap_chatbot_vcn.id
}

resource "oci_core_internet_gateway" "rdap_chatbot_internet_gateway" {
    #Required
    compartment_id = local.compartment_id
    vcn_id = oci_core_vcn.rdap_chatbot_vcn.id

    #Optional
    enabled = true
    display_name = "rdap-chatbot-internet-gateway"
}

resource "oci_core_nat_gateway" "rdap_chatbot_nat_gateway" {
    #Required
    compartment_id = local.compartment_id
    vcn_id = oci_core_vcn.rdap_chatbot_vcn.id

    #Optional
    block_traffic = false
    display_name = "rdap-chatbot-nat-gateway"
}

resource "oci_core_service_gateway" "rdap_chatbot_service_gateway" {
    #Required
    compartment_id = local.compartment_id
    services {
        #Required
        service_id = data.oci_core_services.all_services.services[0].id
    }
    vcn_id = oci_core_vcn.rdap_chatbot_vcn.id

    #Optional
    display_name = "rdap-chatbot-service-gateway"
}

resource "oci_core_subnet" "KubernetesAPIendpointSubnet" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.rdap_chatbot_vcn.id
  cidr_block                 = "10.0.0.0/30"
  display_name               = "Kubernetes-API-endpoint-subnet"
  dns_label                  = "k8sapiendpoint"
  prohibit_public_ip_on_vnic = false # Allows public IPs (Public Subnet)
  prohibit_internet_ingress  = "false"

  # Optional: Attach specific Route Table and Security Lists
  route_table_id             = oci_core_route_table.routetable_KubernetesAPIendpoint.id
  security_list_ids          = [oci_core_security_list.seclist_KubernetesAPIendpoint.id]
}

resource "oci_core_subnet" "workernodes_subnet" {
  cidr_block                 = "10.0.1.0/24"
  compartment_id             = local.compartment_id
  display_name               = "worker-nodes-subnet"
  dns_label                  = "workernodes"
  prohibit_internet_ingress  = "true"
  prohibit_public_ip_on_vnic = "true" # Prohibits public IPs (Private Subnet)

  # Optional: Attach specific Route Table and Security Lists
  route_table_id             = oci_core_route_table.routetable_workernodes.id
  security_list_ids          = [
    oci_core_security_list.seclist_workernodes.id
    ]
  vcn_id                     = oci_core_vcn.rdap_chatbot_vcn.id
}

resource "oci_core_subnet" "loadbalancers_subnet" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.rdap_chatbot_vcn.id
  cidr_block                 = "10.0.2.0/24"
  display_name               = "load-balancers-subnet"
  dns_label                  = "loadbalancers"
  prohibit_public_ip_on_vnic = false # Allows public IPs (Public Subnet)
  prohibit_internet_ingress  = "false"
  # Optional: Attach specific Route Table and Security Lists
  route_table_id             = oci_core_route_table.routetable_serviceloadbalancers.id
  security_list_ids          = [oci_core_security_list.seclist_loadbalancers.id]
}

resource "oci_core_subnet" "bastion_subnet" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.rdap_chatbot_vcn.id
  cidr_block                 = "10.0.3.0/24"
  display_name               = "bastion-subnet"
  dns_label                  = "bastion"
  prohibit_public_ip_on_vnic = false # Allows public IPs (Public Subnet)

  # Optional: Attach specific Route Table and Security Lists
  security_list_ids          = [oci_core_security_list.seclist_bastion.id]
}

resource "oci_core_default_route_table" "default_route_table_rdap_chatbot_vcn" {
    #Required
    compartment_id = local.compartment_id
    manage_default_resource_id = oci_core_vcn.rdap_chatbot_vcn.default_route_table_id

    #Optional
    display_name = "default-route-table-rdap-chatbot-vcn"
    route_rules {
        #Required
        network_entity_id = oci_core_internet_gateway.rdap_chatbot_internet_gateway.id

        #Optional
        description = "Internet Gateway Route Rule"
        destination = "0.0.0.0/0"
        destination_type = "CIDR_BLOCK"
    }
}

resource "oci_core_route_table" "routetable_KubernetesAPIendpoint" {
    #Required
    compartment_id = local.compartment_id
    vcn_id = oci_core_vcn.rdap_chatbot_vcn.id

    #Optional
    display_name = "routetable-KubernetesAPIendpoint"
    route_rules {
        #Required
        network_entity_id = oci_core_internet_gateway.rdap_chatbot_internet_gateway.id

        #Optional
        description = "Internet Gateway Route Rule"
        destination = "0.0.0.0/0"
        destination_type = "CIDR_BLOCK"
    }
}

resource "oci_core_route_table" "routetable_workernodes" {
    compartment_id = local.compartment_id
    display_name = "routetable-Workernodes"
    route_rules {
        description = "NAT Gateway Route Rule"
        destination = "0.0.0.0/0"
        destination_type = "CIDR_BLOCK"
        network_entity_id = oci_core_nat_gateway.rdap_chatbot_nat_gateway.id
        route_type        = "STATIC"
    }
    route_rules {
        description = "Service Gateway Route Rule"
        destination = "all-str-services-in-oracle-services-network"
        destination_type = "SERVICE_CIDR_BLOCK"
        network_entity_id = oci_core_service_gateway.rdap_chatbot_service_gateway.id
        route_type        = "STATIC"
    }
    vcn_id = oci_core_vcn.rdap_chatbot_vcn.id
}

resource "oci_core_route_table" "routetable_serviceloadbalancers" {
    #Required
    compartment_id = local.compartment_id
    vcn_id = oci_core_vcn.rdap_chatbot_vcn.id

    #Optional
    display_name = "routetable-Serviceloadbalancers"
    route_rules {
        #Required
        network_entity_id = oci_core_internet_gateway.rdap_chatbot_internet_gateway.id

        #Optional
        description = "Internet Gateway Route Rule"
        destination = "0.0.0.0/0"
        destination_type = "CIDR_BLOCK"
    }
}

resource "oci_core_security_list" "seclist_KubernetesAPIendpoint" {
    compartment_id = local.compartment_id
    vcn_id = oci_core_vcn.rdap_chatbot_vcn.id
    display_name = "seclist-KubernetesAPIendpoint"

    ingress_security_rules {
        description = "Kubernetes worker to Kubernetes API endpoint communication"
        protocol = "6"
        source = "10.0.1.0/24" # Worker nodes subnet CIDR
        tcp_options {
            source_port_range {
                max = 6443
                min = 6443
            }
        }
   }

    ingress_security_rules {
        description = "Kubernetes worker to control plane communication"
        protocol = "6" # TCP protocol number
        source = "10.0.1.0/24" # Worker nodes subnet CIDR
        tcp_options {
            source_port_range {
                max = 12250
                min = 12250
            }
        }
   }

    ingress_security_rules {
        description = "Path Discovery"
        protocol = "1" # ICMP protocol number
        source = "10.0.1.0/24" # Worker nodes subnet CIDR
        icmp_options {
            type = 3
            code = 4
        }
   }

    ingress_security_rules {
        description = "External access to Kubernetes API endpoint"
        protocol = "6" # TCP protocol number
        source = "10.0.3.0/24" # Bastion host subnet CIDR
        tcp_options {
            source_port_range {
                max = 6443
                min = 6443
            }
        }
   }

   egress_security_rules {
        description = "Allow Kubernetes control plane to communicate with OKE"
        destination_type = "SERVICE_CIDR_BLOCK"
        destination = local.str_service.cidr_block
        protocol = "6" # TCP protocol number
    }

   egress_security_rules {
        description = "Path Discovery"
        destination_type = "SERVICE_CIDR_BLOCK"
        destination = local.str_service.cidr_block
        protocol = "1" # ICMP protocol number
        icmp_options {
            type = 3
            code = 4
        }
    }

   egress_security_rules {
        description = "Allow Kubernetes control plane to communicate with worker nodes"
        destination = "10.0.1.0/24" # Worker nodes subnet CIDR
        protocol = "6" # TCP protocol number
    }

   egress_security_rules {
        description = "Path Discovery"
        destination = "10.0.1.0/24" # Worker nodes subnet CIDR
        protocol = "1" # ICMP protocol number
        icmp_options {
            type = 3
            code = 4
        }
    }

}

resource "oci_core_security_list" "seclist_workernodes" {
    compartment_id = local.compartment_id
    vcn_id = oci_core_vcn.rdap_chatbot_vcn.id
    display_name = "seclist-workernodes"

    ingress_security_rules {
        description = "Allow load balancer to communicate with kube-proxy on worker nodes for health checks and node port traffic"
        protocol    = "all" # TCP protocol number
        source      = "10.0.2.0/24" # Load balancer subnet CIDR
        source_type = "CIDR_BLOCK"
        stateless   = "false"
    }
    ingress_security_rules {
        description = "Allow inbound SSH traffic to managed nodes from bastion host"
        protocol = "6" # TCP protocol number
        source = "10.0.3.0/24" # Bastion host subnet CIDR
        source_type = "CIDR_BLOCK"
        stateless   = "false"
        tcp_options {
            source_port_range {
                max = "22"
                min = "22"
            }
        }
   }
    ingress_security_rules {
        description = "Load balancer to worker nodes node ports communication"
        protocol = "all" # TCP protocol number
        source = "10.0.2.0/24" # Load balancer subnet CIDR
        source_type = "CIDR_BLOCK"
        stateless   = "false"
    }
    ingress_security_rules {
        description = "Allow Kubernetes control plane to communicate with worker nodes"
        protocol = "6" # TCP protocol number
        source = "10.0.0.0/30" # Kubernetes API endpoint subnet CIDR
        source_type = "CIDR_BLOCK"
        stateless   = "false"
    }
    ingress_security_rules {
        description = "Path Discovery"
        protocol = "1" # ICMP protocol number
        source = "0.0.0.0/0" # Kubernetes API endpoint subnet CIDR
        source_type = "CIDR_BLOCK"
        stateless   = "false"
        icmp_options {
            type = 3
            code = 4
        }
   }
    ingress_security_rules {
     description = "Allow pods on one worker node to communicate with pods on other worker nodes"
        protocol = "all"
        source = "10.0.1.0/24" # Worker nodes subnet CIDR
        source_type = "CIDR_BLOCK"
        stateless = "false"
    }
    egress_security_rules {
        description = "Allow worker nodes to communicate with internet"
        destination = "0.0.0.0/0" # Allow all destinations for outbound traffic from worker nodes
        destination_type = "CIDR_BLOCK"
        protocol = "6" # TCP protocol number
        stateless = "false"    
    }

    egress_security_rules {
        description = "Allow worker nodes to communicate with Kubernetes API endpoint"
        destination = "10.0.0.0/30" # Kubernetes API endpoint subnet CIDR
        destination_type = "CIDR_BLOCK"
        protocol = "6" # TCP protocol number
        stateless = "false"
        tcp_options {
            source_port_range {
                max = "6443"
                min = "6443"
            }
        }
    }
   egress_security_rules {
        description = "Path Discovery"
        destination = "0.0.0.0/0" # Allow all destinations for outbound traffic from worker nodes
        destination_type = "CIDR_BLOCK"
        icmp_options {
            code = 4
            type = 3
        }
        protocol = "1" # ICMP protocol number
        stateless = "false"
    }
    egress_security_rules {
        description = "Kubernetes worker to control plane communication"
        destination = "10.0.0.0/30" # Kubernetes API endpoint subnet CIDR
        destination_type = "CIDR_BLOCK"
        protocol = "6" # TCP protocol number
        stateless = "false"
        tcp_options {
            source_port_range {
                max = "12250"
                min = "12250" 
            }
        }
    }
   egress_security_rules {
        description      = "Allow worker nodes to communicate with OKE control plane"
        destination      = "all-str-services-in-oracle-services-network"
        destination_type = "SERVICE_CIDR_BLOCK"
        protocol = "6" # TCP protocol number
        stateless = "false"
    }

   egress_security_rules {
        description = "Allow pods on one worker node to communicate with pods on other worker nodes"
        destination = "10.0.1.0/24" # Worker nodes subnet CIDR
        destination_type = "CIDR_BLOCK"
        protocol = "all" # Allow all protocols for internal communication        
        stateless = "false"
    }
}

resource "oci_core_security_list" "seclist_loadbalancers" {
    compartment_id = local.compartment_id
    vcn_id = oci_core_vcn.rdap_chatbot_vcn.id
    display_name = "seclist-loadbalancers"

    ingress_security_rules {
        description = "Load balancer listener protocol and ports for external access to load balancer"
        protocol = "6" # TCP protocol number
        source = "0.0.0.0/0" # Allow access from any IP
        tcp_options {
            source_port_range {
                max = 80
                min = 80
            }
        }
    }

    egress_security_rules {
        description = "Load balancer to worker nodes node ports"
        protocol = "all" # TCP protocol number
        destination = "10.0.1.0/24" # Worker nodes subnet CIDR
    }

    egress_security_rules {
        description = "Allow load balancer to communicate with kube-proxy on worker nodes for health checks and node port traffic"
        protocol = "all" # TCP protocol number
        destination = "10.0.1.0/24" # Worker nodes subnet CIDR
    }
}

resource "oci_core_security_list" "seclist_bastion" {
    compartment_id = local.compartment_id
    vcn_id = oci_core_vcn.rdap_chatbot_vcn.id
    display_name = "seclist-Bastion"

    egress_security_rules {
        description = "Allow bastion to access the Kubernetes API endpoint"
        protocol = "6" # TCP protocol number
        destination = "10.0.0.0/30" # Kubernetes API endpoint subnet CIDR
        tcp_options {
            source_port_range {
                max = 6443
                min = 6443
            }
        }
    }

    egress_security_rules {
        description = "Allow SSH traffic to worker nodes from bastion host"
        protocol = "6" # TCP protocol number
        destination = "10.0.1.0/24" # Worker nodes subnet CIDR
        tcp_options {
            source_port_range {
                max = 22
                min = 22
            }
        }
    }
}