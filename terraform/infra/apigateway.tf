# ── Variables ─────────────────────────────────────────────────

variable "certificate_id" {
  description = "OCI Certificate OCID (fra OCI Certificates)"
  type        = string
  default     = "ocid1.certificate.oc19.eu-frankfurt-2.amaaaaaalgam66yamvkjdqgunpcxbjdw54wqfadcv7utxirulthahiremnda"
}

variable "custom_hostname" {
  description = "Custom hostname for API Gateway (f.eks. api.elcarocloud.no)"
  type        = string
  default     = "api.elcarocloud.no"
}

# ── Data: hent sql-executor function OCID dynamisk ────────────


# ── API Gateway ───────────────────────────────────────────────

resource "oci_apigateway_gateway" "main" {
  compartment_id = local.compartment_id
  display_name   = "rdap-chatbot-gw"
  endpoint_type  = "PUBLIC"
  subnet_id      = oci_core_subnet.api_gateway_subnet.id

  # Koble sertifikat og custom hostname (fase 2 – etter certbot)
  # Uncomment og fyll inn etter at sertifikatet er importert til OCI Certificates:
  certificate_id = var.certificate_id

  freeform_tags = {
    project = "rdap-chatbot"
  }
}

# ── Deployment ────────────────────────────────────────────────

resource "oci_apigateway_deployment" "v1" {
  compartment_id = local.compartment_id
  gateway_id     = oci_apigateway_gateway.main.id
  display_name   = "rdap-chatbot-v1"
  path_prefix    = "/v1"
  freeform_tags = {
    deployed_at = "2026-06-10-v2"
  }


  specification {

    # ── Gateway-nivå request policies ─────────────────────────
    request_policies {

      cors {
        allowed_origins              = ["*"] # begrens til frontend-domenet i prod
        allowed_methods              = ["POST", "GET", "PUT", "DELETE", "OPTIONS"]
        allowed_headers              = ["Content-Type", "Authorization"]
        max_age_in_seconds           = 3600
        is_allow_credentials_enabled = false
      }

      rate_limiting {
        rate_in_requests_per_second = 10
        rate_key                    = "CLIENT_IP"
      }
    }

    # ── Route: /v1/ask ────────────────────────────────────────
    routes {
      path    = "/ask"
      methods = ["POST", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.sql_executor.id
      }

      request_policies {
        header_validations {
          headers {
            name     = "Content-Type"
            required = true
          }
          validation_mode = "ENFORCING"
        }
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Access-Control-Allow-Methods"
              values    = ["POST, OPTIONS"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Access-Control-Allow-Headers"
              values    = ["Content-Type, Authorization"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "X-Content-Type-Options"
              values    = ["nosniff"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "X-Frame-Options"
              values    = ["DENY"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    # ── Route: /v1/feedback ───────────────────────────────────
    routes {
      path    = "/feedback"
      methods = ["POST", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.feedback_executor.id
      }

      request_policies {
        header_validations {
          headers {
            name     = "Content-Type"
            required = true
          }
          validation_mode = "ENFORCING"
        }
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Access-Control-Allow-Methods"
              values    = ["POST, OPTIONS"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Access-Control-Allow-Headers"
              values    = ["Content-Type, Authorization"]
              if_exists = "OVERWRITE"
            }            
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "X-Content-Type-Options"
              values    = ["nosniff"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "X-Frame-Options"
              values    = ["DENY"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }
    # ── Route: /v1/auth/login ─────────────────────────────────
    routes {
      path    = "/auth/login"
      methods = ["POST", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.auth_handler.id
      }

      request_policies {
        header_transformations {
          set_headers {
            items {
              name      = "X-Auth-Action"
              values    = ["login"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Content-Type"
              values    = ["application/json"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    # ── Route: /v1/auth/refresh ───────────────────────────────
    routes {
      path    = "/auth/refresh"
      methods = ["POST", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.auth_handler.id
      }

      request_policies {
        header_transformations {
          set_headers {
            items {
              name      = "X-Auth-Action"
              values    = ["refresh"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Content-Type"
              values    = ["application/json"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    # ── Route: /v1/auth/logout ────────────────────────────────
    routes {
      path    = "/auth/logout"
      methods = ["POST", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.auth_handler.id
      }

      request_policies {
        header_transformations {
          set_headers {
            items {
              name      = "X-Auth-Action"
              values    = ["logout"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Content-Type"
              values    = ["application/json"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    # ── Route: /v1/auth/forgot-password ──────────────────────
    routes {
      path    = "/auth/forgot-password"
      methods = ["POST", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.auth_handler.id
      }

      request_policies {
        header_transformations {
          set_headers {
            items {
              name      = "X-Auth-Action"
              values    = ["forgot-password"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Content-Type"
              values    = ["application/json"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    # ── Route: /v1/auth/reset-password ───────────────────────
    routes {
      path    = "/auth/reset-password"
      methods = ["POST", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.auth_handler.id
      }

      request_policies {
        header_transformations {
          set_headers {
            items {
              name      = "X-Auth-Action"
              values    = ["reset-password"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Content-Type"
              values    = ["application/json"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    # ── Route: /v1/me ─────────────────────────────────────────
    routes {
      path    = "/me"
      methods = ["GET", "PUT", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.auth_handler.id
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    routes {
      path    = "/chats"
      methods = ["GET", "POST", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.chat_handler.id
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    # ── Route: /v1/chats/{id} ─────────────────────────────────
    routes {
      path    = "/chats/{id}"
      methods = ["DELETE", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.chat_handler.id
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    # ── Route: /v1/chats/{id}/messages ────────────────────────
    routes {
      path    = "/chats/{id}/messages"
      methods = ["GET", "POST", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.chat_handler.id
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    # ── Route: /v1/chats/{id}/title ───────────────────────────
    routes {
      path    = "/chats/{id}/title"
      methods = ["PUT", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.chat_handler.id
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }
    # ── Route: /v1/admin/ai-profiles/{path*} ──────────────────
    routes {
      path    = "/admin/ai-profiles/{path*}"
      methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.ai_profile_handler.id
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    # ── Route: /v1/admin/ai-profiles ──────────────────────────
    # (uten path-suffiks - dekker GET-list og POST-create)
    routes {
      path    = "/admin/ai-profiles"
      methods = ["GET", "POST", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.ai_profile_handler.id
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    # ── Route: /v1/me/ai-profiles ─────────────────────────────
    routes {
      path    = "/me/ai-profiles"
      methods = ["GET", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.ai_profile_handler.id
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }

    # ── Route: /v1/me/ai-profile ──────────────────────────────
    routes {
      path    = "/me/ai-profile"
      methods = ["GET", "PUT", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.ai_profile_handler.id
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }
    # ── Route: /v1/admin/profiles/{path*} ─────────────────────
    routes {
      path    = "/admin/profiles/{path*}"
      methods = ["GET", "PUT", "DELETE", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.profile_handler.id
      }
      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }
    # ── Route: /v1/admin ─────────────────────────────────────
    routes {
      path    = "/admin/{path*}"
      methods = ["GET", "POST", "PUT", "DELETE", "OPTIONS"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.admin_handler.id
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name      = "Access-Control-Allow-Origin"
              values    = ["*"]
              if_exists = "OVERWRITE"
            }
            items {
              name      = "Strict-Transport-Security"
              values    = ["max-age=31536000; includeSubDomains"]
              if_exists = "OVERWRITE"
            }
          }
        }
      }
    }
  }
}

# ── Outputs ───────────────────────────────────────────────────

output "gateway_hostname" {
  description = "OCI-generert hostname – bruk som CNAME-target i GoDaddy"
  value       = oci_apigateway_gateway.main.hostname
}

output "api_endpoint" {
  description = "Base URL til API-et"
  value       = oci_apigateway_deployment.v1.endpoint
}

output "gateway_id" {
  value = oci_apigateway_gateway.main.id
}
