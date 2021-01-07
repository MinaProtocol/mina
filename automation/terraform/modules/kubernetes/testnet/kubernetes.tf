data "google_client_config" "current" {}

data "google_container_cluster" "cluster" {
  name     = var.cluster_name
  location = var.cluster_region
}


provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.cluster.endpoint}"
  client_certificate     = base64decode(data.google_container_cluster.cluster.master_auth[0].client_certificate)
  client_key             = base64decode(data.google_container_cluster.cluster.master_auth[0].client_key)
  cluster_ca_certificate = base64decode(data.google_container_cluster.cluster.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.current.access_token
  # config_context  = var.k8s_context
}


resource "kubernetes_namespace" "testnet_namespace" {
  metadata {
    name = var.testnet_name
  }
}
