terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "= 8.14.0"
      configuration_aliases = [oci.home]
    }
  }

  backend "s3" {
    bucket   = "rdap-chatbot-terraform-state"
    key      = "rdap_chatbot/terraform.tfstate"
    region   = "eu-frankfurt-2"
    endpoint = "https://axpqbvkhoxdj.compat.objectstorage.eu-frankfurt-2.oraclecloud.eu"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    force_path_style            = true
  }
}