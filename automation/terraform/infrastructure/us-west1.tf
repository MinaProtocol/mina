locals {
  west1_region = "us-west1"
  west1_k8s_context = "gke_o1labs-192920_us-west1_mina-integration-west1"

  west1_prometheus_helm_values = {
    server = {
      global = {
        external_labels = {
          origin_prometheus = "west1-prometheus"
        }
      }
      persistentVolume = {
        size = "50Gi"
      }
      remoteWrite = [
        {
          url = jsondecode(data.aws_secretsmanager_secret_version.current_prometheus_remote_write_config.secret_string)["remote_write_uri"]
          basic_auth = {
            username = jsondecode(data.aws_secretsmanager_secret_version.current_prometheus_remote_write_config.secret_string)["remote_write_username"]
            password = jsondecode(data.aws_secretsmanager_secret_version.current_prometheus_remote_write_config.secret_string)["remote_write_password"]
          }
          write_relabel_configs = [
            {
              source_labels: ["__name__"]
              regex: "(container.*|Coda.*)"
              action: "keep"
            }
          ]
        }
      ]
    }
  }
}

provider "google" {
  alias   = "google_west1"
  project = local.gcp_project
  region  = local.west1_region
}

provider "kubernetes" {
  alias   = "k8s_west1"
  config_context = local.west1_k8s_context
}

data "google_compute_zones" "west1_available" {
  project = local.gcp_project
  region = local.west1_region
  status = "UP"
}

### Testnets

resource "google_container_cluster" "mina_integration_west1" {
  provider = google.google_west1
  name     = "mina-integration-west1"
  location = local.west1_region
  min_master_version = "1.16"

  node_locations = data.google_compute_zones.west1_available.names

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}

resource "google_container_node_pool" "west1_integration_primary" {
  provider = google.google_west1
  name       = "mina-integration-primary"
  location   = local.west1_region
  cluster    = google_container_cluster.mina_integration_west1.name
  node_count = 5
  autoscaling {
    min_node_count = 0
    max_node_count = 20
  }
  node_config {
    preemptible  = true
    machine_type = "n1-standard-16"
    disk_size_gb = 100

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
    ]
  }
}

## Data Persistence

resource "kubernetes_storage_class" "west1_ssd" {
  provider = kubernetes.k8s_west1

  count = length(local.storage_reclaim_policies)

  metadata {
    name = "${local.west1_region}-ssd-${lower(local.storage_reclaim_policies[count.index])}"
  }

  storage_provisioner = "kubernetes.io/gce-pd"
  reclaim_policy      = local.storage_reclaim_policies[count.index]
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type = "pd-ssd"
  }
}

resource "kubernetes_storage_class" "west1_standard" {
  provider = kubernetes.k8s_west1

  count = length(local.storage_reclaim_policies)

  metadata {
    name = "${local.west1_region}-standard-${lower(local.storage_reclaim_policies[count.index])}"
  }

  storage_provisioner = "kubernetes.io/gce-pd"
  reclaim_policy      = local.storage_reclaim_policies[count.index]
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type = "pd-standard"
  }
}

## Monitoring

provider helm {
  alias = "helm_west1"
  kubernetes {
    config_context = local.west1_k8s_context
  }
}

resource "helm_release" "west1_prometheus" {
  provider  = helm.helm_west1
  name      = "west1-prometheus"
  chart     = "stable/prometheus"
  namespace = "default"
  values = [
    yamlencode(local.west1_prometheus_helm_values)
  ]
  wait       = true
  depends_on = [google_container_cluster.mina_integration_west1]
  force_update  = true
}
