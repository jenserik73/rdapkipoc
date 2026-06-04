data "oci_identity_fault_domains" "fds" {
  compartment_id      = local.compartment_id
  availability_domain = data.oci_identity_availability_domain.ads.name
}