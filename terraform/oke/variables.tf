locals {
    config_data = jsondecode(file("${path.module}/../bootstrap/output.json"))
    compartment_id = local.config_data.rdap_chatbotdev_cmp_ocid.value
    container_repository_display_name = "rdap-chatbot-container-rep"
    container_repository_is_immutable = false
    container_repository_is_public = true
    container_repository_readme_content = "Readme content"
    container_repository_readme_format = " text/markdown"
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