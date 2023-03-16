data "google_client_config" "current" {}

provider "kubernetes" {
  alias          = "testnet_deploy"
  config_context = var.k8s_context
}

resource "kubernetes_namespace" "testnet_namespace" {
  metadata {
    name = var.testnet_name
  }

  timeouts {
    delete = "15m"
  }
}

resource "kubernetes_persistent_volume_claim" "block-producers-pvc" {
  count = var.enable_working_dir_persitence ? length(local.block_producer_vars.blockProducerConfigs) : 0
  metadata {
    name = format("pvc-%s", local.block_producer_vars.blockProducerConfigs[count.index].name)
    namespace  = kubernetes_namespace.testnet_namespace.metadata[0].name
  }
 
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "standard"
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "seed-pvc" {
  count = var.enable_working_dir_persitence ? length(local.seed_vars.seedConfigs) : 0
 
  metadata {
    name = format("pvc-%s",local.seed_vars.seedConfigs[count.index].name)
    namespace  = kubernetes_namespace.testnet_namespace.metadata[0].name
  }
 
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "standard"
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "snark-cordinator-pvc" {
  count = var.enable_working_dir_persitence ? length(local.snark_vars) : 0
 
  metadata {
    name = format("pvc-%s",local.snark_vars[count.index].coordinatorName)
    namespace  = kubernetes_namespace.testnet_namespace.metadata[0].name
  }
 
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "standard"
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "snark-worker-pvc" {
  count = var.enable_working_dir_persitence ? length(local.snark_vars) : 0
 
  metadata {
    name = format("cov-%s",local.snark_vars[count.index].workerName)
    namespace  = kubernetes_namespace.testnet_namespace.metadata[0].name
  }
 
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "standard"
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}

resource "kubernetes_persistent_volume_claim" "archive-pvc" {
  count = var.enable_working_dir_persitence ? length(local.archive_vars) : 0
 
  metadata {
    name = format("cov-%s",local.archive_vars[count.index].archive.name)
    namespace  = kubernetes_namespace.testnet_namespace.metadata[0].name
  }
 
  spec {
    access_modes = ["ReadWriteOnce"]
    storage_class_name = "standard"
    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}