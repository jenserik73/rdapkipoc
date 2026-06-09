# ── Variables ─────────────────────────────────────────────────────────────────

variable "GODADDY_API_KEY" {
  description = "GoDaddy API key for cert-manager DNS01 challenge"
  type        = string
  sensitive   = true
}

variable "GODADDY_API_SECRET" {
  description = "GoDaddy API secret for cert-manager DNS01 challenge"
  type        = string
  sensitive   = true
}

variable "letsencrypt_email" {
  description = "Email address for Let's Encrypt certificate notifications"
  type        = string
  default     = "jens.erik.myhra@sykehuspartner.no"
}

# ── Data: kubeconfig for OKE cluster ──────────────────────────────────────────

data "oci_containerengine_cluster_kube_config" "oke_kubeconfig" {
  cluster_id = oci_containerengine_cluster.rdap_chatbot_oke_cluster.id
}

# ── Providers: Helm + Kubernetes ──────────────────────────────────────────────

provider "helm" {
  kubernetes = {
    host                   = yamldecode(data.oci_containerengine_cluster_kube_config.oke_kubeconfig.content)["clusters"][0]["cluster"]["server"]
    cluster_ca_certificate = base64decode(yamldecode(data.oci_containerengine_cluster_kube_config.oke_kubeconfig.content)["clusters"][0]["cluster"]["certificate-authority-data"])
    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "oci"
      args = [
        "ce", "cluster", "generate-token",
        "--cluster-id", oci_containerengine_cluster.rdap_chatbot_oke_cluster.id,
        "--region", "eu-frankfurt-2"
      ]
    }
  }
}

provider "kubernetes" {
  host                   = yamldecode(data.oci_containerengine_cluster_kube_config.oke_kubeconfig.content)["clusters"][0]["cluster"]["server"]
  cluster_ca_certificate = base64decode(yamldecode(data.oci_containerengine_cluster_kube_config.oke_kubeconfig.content)["clusters"][0]["cluster"]["certificate-authority-data"])
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "oci"
    args = [
      "ce", "cluster", "generate-token",
      "--cluster-id", oci_containerengine_cluster.rdap_chatbot_oke_cluster.id,
      "--region", "eu-frankfurt-2"
    ]
  }
}

# ── cert-manager ──────────────────────────────────────────────────────────────

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.17.0"

  values = [<<-EOT
    installCRDs: true
  EOT
  ]

  depends_on = [oci_containerengine_node_pool.rdap_chatbot_oke_node_pool]
}

# ── ingress-nginx ─────────────────────────────────────────────────────────────

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  namespace        = "ingress-nginx"
  create_namespace = true

  depends_on = [oci_containerengine_node_pool.rdap_chatbot_oke_node_pool]
}

# ── godaddy-webhook ───────────────────────────────────────────────────────────

resource "helm_release" "godaddy_webhook" {
  name             = "godaddy-webhook"
  repository       = "https://snowdrop.github.io/godaddy-webhook"
  chart            = "godaddy-webhook"
  namespace        = "cert-manager"
  create_namespace = false


  depends_on = [helm_release.cert_manager]
}

# ── GoDaddy API secret ────────────────────────────────────────────────────────

resource "kubernetes_secret_v1" "godaddy_api_key" {
  metadata {
    name      = "godaddy-api-key"
    namespace = "cert-manager"
  }

  data = {
    token = "${var.GODADDY_API_KEY}:${var.GODADDY_API_SECRET}"
  }

  depends_on = [helm_release.godaddy_webhook]
}

# ── ClusterIssuer ─────────────────────────────────────────────────────────────

resource "kubernetes_manifest" "cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-godaddy"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "letsencrypt-godaddy-key"
        }
        solvers = [{
          dns01 = {
            webhook = {
              groupName  = "acme.mycompany.com"
              solverName = "godaddy"
              config = {
                apiKeySecretRef = {
                  name = "godaddy-api-key"
                  key  = "token"
                }
                production = true
                ttl        = 600
              }
            }
          }
        }]
      }
    }
  }

  depends_on = [
    helm_release.godaddy_webhook,
    kubernetes_secret_v1.godaddy_api_key
  ]
}

# ── OCIR pull secret ──────────────────────────────────────────────────────────

variable "OCIR_USERNAME" {
  description = "OCIR username (namespace/email)"
  type        = string
  default     = "axpqbvkhoxdj/jens.erik.myhra@sykehuspartner.no"
}

variable "OCIR_PASSWORD" {
  description = "OCI auth token for OCIR"
  type        = string
  sensitive   = true
}

resource "kubernetes_secret_v1" "ocir_secret" {
  metadata {
    name      = "ocir-secret"
    namespace = "default"
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = jsonencode({
      auths = {
        "ocir.eu-frankfurt-2.oci.oraclecloud.eu" = {
          username = var.OCIR_USERNAME
          password = var.OCIR_PASSWORD
          auth     = base64encode("${var.OCIR_USERNAME}:${var.OCIR_PASSWORD}")
        }
      }
    })
  }

  depends_on = [oci_containerengine_node_pool.rdap_chatbot_oke_node_pool]
}

# ── Security list: port 443 på load balancer subnet ───────────────────────────
# NB: Legg til denne ingress-regelen i seclist_loadbalancers i network.tf:
#
#   ingress_security_rules {
#     description = "Load balancer listener - HTTPS on port 443"
#     protocol    = "6"
#     source      = "0.0.0.0/0"
#     tcp_options {
#       min = 443
#       max = 443
#     }
#   }

# ── Outputs ───────────────────────────────────────────────────────────────────

output "ingress_nginx_namespace" {
  value = helm_release.ingress_nginx.namespace
}

output "cert_manager_namespace" {
  value = helm_release.cert_manager.namespace
}
