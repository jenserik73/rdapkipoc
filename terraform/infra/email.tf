# ── OCI Email Delivery ────────────────────────────────────────

resource "oci_email_sender" "querychat_sender" {
  compartment_id = local.compartment_id
  email_address  = "noreply@elcarocloud.no"
}

# ── Outputs ───────────────────────────────────────────────────

output "email_sender_id" {
  description = "OCID for godkjent avsender"
  value       = oci_email_sender.querychat_sender.id
}

output "smtp_host" {
  description = "SMTP hostname for OCI Email Delivery i eu-frankfurt-2"
  value       = "smtp.email.eu-frankfurt-2.oci.oraclecloud.eu"
}