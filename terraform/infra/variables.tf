locals {
    config_data = jsondecode(file("${path.module}/../bootstrap/output.json"))
    compartment_id = local.config_data.rdap_chatbotdev_cmp_ocid.value
    container_repository_display_name = "rdap-chatbot-container-rep"
    container_repository_is_immutable = false
    container_repository_is_public = true
    container_repository_readme_content = "Readme content"
    container_repository_readme_format = " text/markdown"
}

variable "vcn_cidr_blocks" {
    description = "CIDR blocks for the VCN"
    type = list(string)
    default = ["10.0.0.0/16"]
}

variable "vcn_display_name" {
    description = "Display name for the VCN"
    type = string
    default = "rdap-chatbot-vcn"
} 

variable "vcn_dns_label" {
    description = "DNS label for the VCN"
    type = string
    default = "rdapchatbotvcn"
}

variable "vcn_ipv6private_cidr_blocks" {
    description = "IPv6 private CIDR blocks for the VCN"
    type = list(string)
    default = []
}

variable "vcn_is_ipv6enabled" {
    description = "Whether IPv6 is enabled for the VCN"
    type = bool
    default = false
}

variable "vcn_is_oracle_gua_allocation_enabled" {
    description = "Whether Oracle GUA allocation is enabled for the VCN"
    type = bool
    default = false
}

variable "vcn_security_attributes" {
    description = "Security attributes for the VCN"
    type = map(string)
    default = {}
}

variable "subnet_availability_domain" {
    description = "Availability domain for the subnet"
    type = string
    default = null
}

variable "subnet_cidr_block" {
    description = "CIDR block for the subnet"
    type = string
    default = ""
}

variable "subnet_display_name" {
    description = "Display name for the subnet"
    type = string
    default = "rdap-chatbot-subnet"
} 

variable "subnet_dns_label" {
    description = "DNS label for the subnet"
    type = string
    default = "rdapchatbotsubnet"
} 

variable "subnet_ipv4cidr_blocks" {
    description = "IPv4 CIDR blocks for the subnet"
    type = list(string)
    default = []
}

variable "subnet_prohibit_internet_ingress" {
    description = "Whether to prohibit internet ingress for the subnet"
    type = bool
    default = false
}

variable "subnet_prohibit_public_ip_on_vnic" {
    description = "Whether to prohibit public IP on VNICs in the subnet"
    type = bool
    default = false
}

variable "subnet_security_list_ids" {
    description = "Security list IDs for the subnet"
    type = list(string)
    default = []
}

variable "subnet_route_table_id" {
    description = "Route table ID for the subnet"
    type = string
    default = null
}

output "compartment_id" {
  value = local.compartment_id
}

output "container_repository_display_name" {
  value = local.container_repository_display_name
}

output "container_repository_is_immutable" {
  value = local.container_repository_is_immutable
}

output "container_repository_is_public" {
  value = local.container_repository_is_public
}

output "container_repository_readme_content" {
  value = local.container_repository_readme_content
}

output "container_repository_readme_format" {
  value = local.container_repository_readme_format
}