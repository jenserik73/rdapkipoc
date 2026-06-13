locals {
  config_data                        = jsondecode(file("${path.module}/../bootstrap/output.json"))
  compartment_id                     = local.config_data.rdap_chatbotdev_cmp_ocid.value
  container_repository_display_name  = "rdap-chatbot-container-rep"
  container_repository_is_immutable  = false
  container_repository_is_public     = true
  container_repository_readme_content = "Readme content"
  container_repository_readme_format = "text/markdown"
  kubernetes_version                 = "v1.34.2"
  admin_instance_ssh_public_key      = file(pathexpand("~/.ssh/ssh-key.key.pub"))
  certbot_instance_ssh_public_key    = file(pathexpand("~/.ssh/ssh-key.key.pub"))
}

# ── Provider Configuration ───────────────────────────────────────────────────

variable "codespace_public_cidr_block" {
  description = "Public IP address of the Codespace"
  type        = string
  default     = "4.180.183.243/32"
}

# ── VCN ──────────────────────────────────────────────────────────────────────

variable "vcn_cidr_blocks" {
  description = "CIDR blocks for the VCN"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "vcn_display_name" {
  description = "Display name for the VCN"
  type        = string
  default     = "rdap-chatbot-vcn"
}

variable "vcn_dns_label" {
  description = "DNS label for the VCN"
  type        = string
  default     = "rdapchatbotvcn"
}

variable "vcn_is_ipv6enabled" {
  description = "Whether IPv6 is enabled for the VCN"
  type        = bool
  default     = false
}

variable "vcn_security_attributes" {
  description = "Security attributes for the VCN"
  type        = map(string)
  default     = {}
}

# ── Secrets ───────────────────────────────────────────────────────────────────

variable "RDAPKIPOCDB_PASSWORD" {
  description = "Password for the RDAP Chatbot Autonomous Database user"
  type        = string
  sensitive   = true
}

variable "wallet_file_path" {
  description = "Local path to the slim ADB wallet zip file"
  type        = string
  default     = "/home/vscode/oracle_wallet/wallet_rdapkipocdb_slim.zip"
}

variable "RDAPKIPOCDB_WALLET_PASSWORD" {
  description = "Password for the RDAP Chatbot Autonomous Database wallet"
  type        = string
  sensitive   = true
}

variable "QUERYCHAT_JWT_SECRET" {
  description = "Secret for signing JWT access tokens"
  type        = string
  sensitive   = true
}

variable "QUERYCHAT_REFRESH_SECRET" {
  description = "Secret for signing refresh tokens"
  type        = string
  sensitive   = true
}

variable "QUERYCHAT_SMTP_PASSWORD" {
  description = "SMTP password for OCI Email Delivery"
  type        = string
  sensitive   = true
}

# ── Compute ───────────────────────────────────────────────────────────────────

# ── Outputs ───────────────────────────────────────────────────────────────────

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
