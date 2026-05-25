resource "oci_functions_application" "test_application" {
    # Required
    compartment_id = local.compartment_id
    display_name   = "my-function-application"
    subnet_ids     = [var.subnet_ocid]

    # Optional: Enable logging
    config = {
        "LOG_LEVEL" = "INFO"
    }
    
    # Optional: Define trace configuration
    trace_config {
        is_enabled = true
        domain_id  = var.trace_domain_ocid
    }
}
