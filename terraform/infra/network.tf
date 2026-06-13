# ── VCN ──────────────────────────────────────────────────────────────────────

resource "oci_core_vcn" "rdap_chatbot_vcn" {
  compartment_id = local.compartment_id
  cidr_blocks    = var.vcn_cidr_blocks
  display_name   = var.vcn_display_name
  dns_label      = var.vcn_dns_label
  is_ipv6enabled = var.vcn_is_ipv6enabled
}

output "vcn_id" {
  value = oci_core_vcn.rdap_chatbot_vcn.id
}

# ── Gateways ──────────────────────────────────────────────────────────────────

resource "oci_core_internet_gateway" "rdap_chatbot_internet_gateway" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  enabled        = true
  display_name   = "rdap-chatbot-internet-gateway"
}

resource "oci_core_nat_gateway" "rdap_chatbot_nat_gateway" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  block_traffic  = false
  display_name   = "rdap-chatbot-nat-gateway"
}

resource "oci_core_service_gateway" "rdap_chatbot_service_gateway" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "rdap-chatbot-service-gateway"

  services {
    service_id = data.oci_core_services.all_services.services[0].id
  }
}

# ── Subnets ───────────────────────────────────────────────────────────────────

resource "oci_core_subnet" "functions_subnet" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.rdap_chatbot_vcn.id
  cidr_block                 = "10.0.4.0/24"
  display_name               = "functions-subnet"
  dns_label                  = "functions"
  prohibit_internet_ingress  = true
  prohibit_public_ip_on_vnic = true
  route_table_id             = oci_core_route_table.routetable_functions.id
  security_list_ids          = [oci_core_security_list.seclist_functions.id]
}

resource "oci_core_subnet" "api_gateway_subnet" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.rdap_chatbot_vcn.id
  cidr_block                 = "10.0.5.0/24"
  display_name               = "api-gateway-subnet"
  dns_label                  = "api"
  prohibit_public_ip_on_vnic = false # Public subnet
  route_table_id             = oci_core_route_table.routetable_api_gateway.id
  security_list_ids          = [oci_core_security_list.seclist_api_gateway.id]
}

resource "oci_core_subnet" "KubernetesAPIendpointSubnet" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.rdap_chatbot_vcn.id
  cidr_block                 = "10.0.0.0/30"
  display_name               = "Kubernetes-API-endpoint-subnet"
  dns_label                  = "k8sapiendpoint"
  prohibit_public_ip_on_vnic = false # Public subnet
  prohibit_internet_ingress  = false
  route_table_id             = oci_core_route_table.routetable_KubernetesAPIendpoint.id
  security_list_ids          = [oci_core_security_list.seclist_KubernetesAPIendpoint.id]
}

resource "oci_core_subnet" "workernodes_subnet" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.rdap_chatbot_vcn.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "worker-nodes-subnet"
  dns_label                  = "workernodes"
  prohibit_internet_ingress  = true
  prohibit_public_ip_on_vnic = true # Private subnet
  route_table_id             = oci_core_route_table.routetable_workernodes.id
  security_list_ids          = [oci_core_security_list.seclist_workernodes.id]
}

resource "oci_core_subnet" "loadbalancers_subnet" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.rdap_chatbot_vcn.id
  cidr_block                 = "10.0.2.0/24"
  display_name               = "load-balancers-subnet"
  dns_label                  = "loadbalancers"
  prohibit_public_ip_on_vnic = false # Public subnet
  prohibit_internet_ingress  = false
  route_table_id             = oci_core_route_table.routetable_serviceloadbalancers.id
  security_list_ids          = [oci_core_security_list.seclist_loadbalancers.id]
}

resource "oci_core_subnet" "bastion_subnet" {
  compartment_id             = local.compartment_id
  vcn_id                     = oci_core_vcn.rdap_chatbot_vcn.id
  cidr_block                 = "10.0.3.0/24"
  display_name               = "bastion-subnet"
  dns_label                  = "bastion"
  prohibit_public_ip_on_vnic = false # Public subnet
  route_table_id             = oci_core_route_table.routetable_bastion.id
  security_list_ids          = [oci_core_security_list.seclist_bastion.id]
}

# ── Route tables ──────────────────────────────────────────────────────────────

resource "oci_core_default_route_table" "default_route_table_rdap_chatbot_vcn" {
  compartment_id             = local.compartment_id
  manage_default_resource_id = oci_core_vcn.rdap_chatbot_vcn.default_route_table_id
  display_name               = "default-route-table-rdap-chatbot-vcn"

  route_rules {
    description       = "Internet Gateway Route Rule"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.rdap_chatbot_internet_gateway.id
  }
}

resource "oci_core_route_table" "routetable_bastion" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "routetable-bastion"

  route_rules {
    description       = "Internet Gateway Route Rule"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.rdap_chatbot_internet_gateway.id
    route_type        = "STATIC"
  }
}

resource "oci_core_route_table" "routetable_api_gateway" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "routetable-api-gateway"

  route_rules {
    description       = "Internet Gateway Route Rule"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.rdap_chatbot_internet_gateway.id
    route_type        = "STATIC"
  }
}

resource "oci_core_route_table" "routetable_functions" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "routetable-functions"

  route_rules {
    description       = "Service Gateway Route Rule"
    destination       = "all-str-services-in-oracle-services-network"
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.rdap_chatbot_service_gateway.id
    route_type        = "STATIC"
  }

  route_rules {
    description       = "NAT Gateway Route Rule"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.rdap_chatbot_nat_gateway.id
    route_type        = "STATIC"
  }
}

resource "oci_core_route_table" "routetable_KubernetesAPIendpoint" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "routetable-KubernetesAPIendpoint"

  route_rules {
    description       = "Internet Gateway Route Rule"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.rdap_chatbot_internet_gateway.id
  }
}

resource "oci_core_route_table" "routetable_workernodes" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "routetable-Workernodes"

  route_rules {
    description       = "NAT Gateway Route Rule"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_nat_gateway.rdap_chatbot_nat_gateway.id
    route_type        = "STATIC"
  }

  route_rules {
    description       = "Service Gateway Route Rule"
    destination       = "all-str-services-in-oracle-services-network"
    destination_type  = "SERVICE_CIDR_BLOCK"
    network_entity_id = oci_core_service_gateway.rdap_chatbot_service_gateway.id
    route_type        = "STATIC"
  }
}

resource "oci_core_route_table" "routetable_serviceloadbalancers" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "routetable-Serviceloadbalancers"

  route_rules {
    description       = "Internet Gateway Route Rule"
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.rdap_chatbot_internet_gateway.id
  }
}

# ── Security lists ────────────────────────────────────────────────────────────

resource "oci_core_security_list" "seclist_api_gateway" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "seclist-api-gateway"

  ingress_security_rules {
    description = "Allow SSH from allowed CIDRs"
    source      = var.codespace_public_cidr_block
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 22
      max = 22
    }
  }
  ingress_security_rules {
    description = "Allow HTTP traffic from anywhere"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 80
      max = 80
    }
  }
  ingress_security_rules {
    description = "Allow HTTP traffic from anywhere"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 443
      max = 443
    }
  }
  ingress_security_rules {
    description = "Allow Ping (ICMP) from anywhere"
    source      = "0.0.0.0/0" # Allow from anywhere; restrict to your IP/CIDR for better security
    source_type = "CIDR_BLOCK"
    protocol    = "1" # ICMP protocol number
    icmp_options {
      type = 8 # Echo Request (Ping)
      code = 0 # Code 0 is required for Echo Request
    }
  }
  ingress_security_rules {
    description = "Allow SSH traffic from Bastion subnet"
    source      = "10.0.3.0/24"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    stateless   = false
    tcp_options {
      min = 22
      max = 22
    }
  }
  egress_security_rules {
    description      = "Allow traffic to all Oracle services in the network"
    destination      = "all-str-services-in-oracle-services-network"
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol         = "6"
    stateless        = false
  }
  egress_security_rules {
    description      = "Allow HTTPS outbound via NAT"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    stateless        = false
    tcp_options {
      min = 443
      max = 443
    }
  }
}

resource "oci_core_security_list" "seclist_functions" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "seclist-functions"

  ingress_security_rules {
    description = "Allow SSH traffic from Bastion subnet"
    source      = "10.0.3.0/24"
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    stateless   = false
    tcp_options {
      min = 22
      max = 22
    }
  }

  egress_security_rules {
    description      = "Allow traffic to all Oracle services in the network"
    destination      = "all-str-services-in-oracle-services-network"
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol         = "6"
    stateless        = false
  }
  egress_security_rules {
    description      = "Allow outbound traffic on port 1522 to Oracle Autonomous Database"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    stateless        = false
    tcp_options {
      min = 1522
      max = 1522
    }
  }
  egress_security_rules {
    description      = "Allow HTTPS outbound via NAT"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    stateless        = false
    tcp_options {
      min = 443
      max = 443
    }
  }
  egress_security_rules {
    description      = "Allow SMTP outbound via NAT (OCI Email Delivery)"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    stateless        = false
    tcp_options {
      min = 587
      max = 587
    }
  }
egress_security_rules {
    description      = "Allow SMTP_SSL outbound via NAT (OCI Email Delivery port 465)"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    stateless        = false
    tcp_options {
      min = 465
      max = 465
    }
  }
}

resource "oci_core_security_list" "seclist_KubernetesAPIendpoint" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "seclist-KubernetesAPIendpoint"

  ingress_security_rules {
    description = "Kubernetes worker to Kubernetes API endpoint communication"
    protocol    = "6"
    source      = "10.0.1.0/24"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  ingress_security_rules {
    description = "Kubernetes worker to control plane communication"
    protocol    = "6"
    source      = "10.0.1.0/24"
    tcp_options {
      min = 12250
      max = 12250
    }
  }

  ingress_security_rules {
    description = "Path Discovery"
    protocol    = "1"
    source      = "10.0.1.0/24"
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    description = "External access to Kubernetes API endpoint"
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  egress_security_rules {
    description      = "Allow Kubernetes control plane to communicate with OKE"
    destination_type = "SERVICE_CIDR_BLOCK"
    destination      = "all-str-services-in-oracle-services-network"
    protocol         = "6"
  }

  egress_security_rules {
    description = "Allow Kubernetes control plane to communicate with worker nodes"
    destination = "10.0.1.0/24"
    protocol    = "6"
  }

  egress_security_rules {
    description = "Path Discovery"
    destination = "10.0.1.0/24"
    protocol    = "1"
    icmp_options {
      type = 3
      code = 4
    }
  }
}

resource "oci_core_security_list" "seclist_workernodes" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "seclist-workernodes"

  ingress_security_rules {
    description = "Allow load balancer to communicate with kube-proxy on worker nodes"
    protocol    = "all"
    source      = "10.0.2.0/24"
    source_type = "CIDR_BLOCK"
    stateless   = false
  }

  ingress_security_rules {
    description = "Allow inbound SSH traffic to managed nodes from Internet"
    protocol    = "6"
    source      = "0.0.0.0/0"
    source_type = "CIDR_BLOCK"
    stateless   = false
    tcp_options {
      min = 22
      max = 22
    }
  }

  ingress_security_rules {
    description = "Allow Kubernetes control plane to communicate with worker nodes"
    protocol    = "6"
    source      = "10.0.0.0/30"
    source_type = "CIDR_BLOCK"
    stateless   = false
  }

  ingress_security_rules {
    description = "Path Discovery"
    protocol    = "1"
    source      = "10.0.0.0/30"
    source_type = "CIDR_BLOCK"
    stateless   = false
    icmp_options {
      type = 3
      code = 4
    }
  }

  ingress_security_rules {
    description = "Allow pods on one worker node to communicate with pods on other worker nodes"
    protocol    = "all"
    source      = "10.0.1.0/24"
    source_type = "CIDR_BLOCK"
    stateless   = false
  }

  egress_security_rules {
    description      = "Allow worker nodes to communicate with internet"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }

  egress_security_rules {
    description      = "Allow worker nodes to communicate with Kubernetes API endpoint"
    destination      = "10.0.0.0/30"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    stateless        = false
    tcp_options {
      min = 6443
      max = 6443
    }
  }

  egress_security_rules {
    description      = "Path Discovery"
    destination      = "0.0.0.0/0"
    destination_type = "CIDR_BLOCK"
    protocol         = "1"
    stateless        = false
    icmp_options {
      type = 3
      code = 4
    }
  }

  egress_security_rules {
    description      = "Kubernetes worker to control plane communication"
    destination      = "10.0.0.0/30"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    stateless        = false
    tcp_options {
      min = 12250
      max = 12250
    }
  }

  egress_security_rules {
    description      = "Path Discovery to Kubernetes API endpoint subnet"
    destination      = "10.0.0.0/30"
    destination_type = "CIDR_BLOCK"
    protocol         = "1"
    stateless        = false
    icmp_options {
      type = 3
      code = 4
    }
  }

  egress_security_rules {
    description      = "Allow worker nodes to communicate with OKE control plane"
    destination      = "all-str-services-in-oracle-services-network"
    destination_type = "SERVICE_CIDR_BLOCK"
    protocol         = "6"
    stateless        = false
    tcp_options {
      min = 443
      max = 443
    }
  }

  egress_security_rules {
    description      = "Allow pods on one worker node to communicate with pods on other worker nodes"
    destination      = "10.0.1.0/24"
    destination_type = "CIDR_BLOCK"
    protocol         = "all"
    stateless        = false
  }
}

resource "oci_core_security_list" "seclist_loadbalancers" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "seclist-loadbalancers"

  ingress_security_rules {
    description = "Load balancer listener - external access on port 80"
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }
  ingress_security_rules {
    description = "Load balancer listener - HTTPS on port 443"
    protocol    = "6"
    source      = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }
  egress_security_rules {
    description = "Load balancer to worker nodes node ports"
    protocol    = "all"
    destination = "10.0.1.0/24"
  }

  egress_security_rules {
    description = "Allow load balancer to communicate with kube-proxy on worker nodes for health checks"
    protocol    = "all"
    destination = "10.0.1.0/24"
  }
}

resource "oci_core_security_list" "seclist_bastion" {
  compartment_id = local.compartment_id
  vcn_id         = oci_core_vcn.rdap_chatbot_vcn.id
  display_name   = "seclist-Bastion"

  ingress_security_rules {
    description = "Allow SSH from allowed CIDRs"
    source      = var.codespace_public_cidr_block
    source_type = "CIDR_BLOCK"
    protocol    = "6"
    tcp_options {
      min = 22
      max = 22
    }
  }
  egress_security_rules {
    description = "Allow bastion to access the Kubernetes API endpoint"
    protocol    = "6"
    destination = "10.0.0.0/30"
    tcp_options {
      min = 6443
      max = 6443
    }
  }
  egress_security_rules {
    description = "Allow SSH traffic to worker nodes from bastion host"
    protocol    = "6"
    destination = "10.0.1.0/24"
    tcp_options {
      min = 22
      max = 22
    }
  }
  egress_security_rules {
    description      = "Allow SSH to functions subnet from bastion host"
    destination      = "10.0.4.0/24"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    tcp_options {
      min = 22
      max = 22
    }
  }
  egress_security_rules {
    description      = "Allow SSH to api-gateway subnet from bastion host"
    destination      = "10.0.5.0/24"
    destination_type = "CIDR_BLOCK"
    protocol         = "6"
    tcp_options {
      min = 22
      max = 22
    }
  }
}
