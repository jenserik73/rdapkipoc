# ── OCI Email Delivery ────────────────────────────────────────

resource "oci_email_sender" "querychat_sender" {
  compartment_id = local.compartment_id
  email_address  = "noreply@elcarocloud.no"
}

resource "oci_email_email_domain" "querychat_domain" {
  compartment_id = local.compartment_id
  name           = "elcarocloud.no"
}

resource "oci_email_dkim" "querychat_dkim" {
  email_domain_id = oci_email_email_domain.querychat_domain.id
  name            = "querychat"
}


# ── Outputs ───────────────────────────────────────────────────

output "dkim_dns_record_name" {
  description = "DKIM DNS TXT record name (legg til i GoDaddy)"
  value       = oci_email_dkim.querychat_dkim.dns_subdomain_name
}

output "dkim_dns_record_value" {
  description = "DKIM DNS TXT record value (legg til i GoDaddy)"
  value       = oci_email_dkim.querychat_dkim.cname_record_value
}

output "email_sender_id" {
  description = "OCID for godkjent avsender"
  value       = oci_email_sender.querychat_sender.id
}

output "smtp_host" {
  description = "SMTP hostname for OCI Email Delivery i eu-frankfurt-2"
  value       = "smtp.email.eu-frankfurt-2.oci.oraclecloud.eu"
}