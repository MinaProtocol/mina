data "google_client_config" "current" {}

data "google_container_cluster" "cluster" {
  name     = var.cluster_name
  location = var.cluster_region
}

provider "kubernetes" {
  config_context  = var.k8s_context
}

resource "kubernetes_namespace" "testnet_namespace" {
  metadata {
    name = var.testnet_name
  }
}
