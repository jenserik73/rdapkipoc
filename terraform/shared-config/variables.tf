locals {
    tenancy_id              = "ocid1.tenancy.oc19..aaaaaaaadu4nynpyltw2mbzb7qhmimjldhzpasq5vzffcv7mkw67vy5fnd3a"
    region                  = "eu-frankfurt-2"
    compartment_name         = "rdap-chatbot-cmp"
    bucket_name              = "rdap-chatbot-terraform-state"
    compartment_description  = "Compartment for rdap chatbot resources"
    bucket_key               = "rdap_chatbot/terraform.tfstate"
}

output "tenancy_id" {
  value = local.tenancy_id
}

output "region" {
  value = local.region
}

output "compartment_name" {
  value = local.compartment_name
}

output "compartment_description" {
  value = local.compartment_description
}

output "bucket_name" {
  value = local.bucket_name
}

output "bucket_key" {
  value = local.bucket_key
}