data "google_client_config" "current" {}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

resource "kubernetes_namespace" "testnet_namespace" {
  metadata {
    name = var.testnet_name
  }

  timeouts {
    delete = "15m"
  }
}
