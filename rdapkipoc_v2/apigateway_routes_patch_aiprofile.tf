# ── Nye routes-blokker for ai-profile-handler ──────────────────────────────
# Legg disse inn i oci_apigateway_deployment "v1" -> specification, FØR
# eksisterende "/admin/{path*}"-ruten (samme prinsipp som /admin/profiles/*
# fra tidligere - mer spesifikke ruter må stå før wildcard-ruten).

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
