data "oci_identity_availability_domain" "ads" {
  compartment_id = local.compartment_id
  ad_number      = 1
}
