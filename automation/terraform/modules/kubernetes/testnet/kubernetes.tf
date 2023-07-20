# data "google_client_config" "current" {}

provider "kubernetes" {
  alias          = "testnet_deploy"
  config_context = var.k8s_context
  config_path    = "~/.kube/config" # Path to your K3s kubeconfig file
  host           = "https://0.0.0.0:80"
}

# provider "kubernetes" {
#   alias                   = "testnet_deploy"
#   config_path             = "~/.kube/config"  # Path to your K3s kubeconfig file

#   config_context_overrides {
#     "cluster"   = var.k8s_context  # Name of your K3s cluster context
#     # "namespace" = "default"  # Namespace to use for Terraform-managed resources
#   }
# }

resource "kubernetes_namespace" "testnet_namespace" {
  provider = kubernetes.testnet_deploy

  metadata {
    name = var.testnet_name
  }

  timeouts {
    delete = "15m"
  }
}
