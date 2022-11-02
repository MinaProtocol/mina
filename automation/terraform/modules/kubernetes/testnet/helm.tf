# Cluster-Local Seed Node

resource "kubernetes_role_binding" "helm_release" {
  metadata {
    name      = "admin-role"
    namespace = kubernetes_namespace.testnet_namespace.metadata[0].name
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "admin"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "default"
    namespace = kubernetes_namespace.testnet_namespace.metadata[0].name
  }
}

resource "helm_release" "seeds" {
  provider = helm.testnet_deploy
  count    = length(local.seed_vars.seedConfigs) > 0 ? 1 : 0

  name       = "${var.testnet_name}-seeds"
  repository = var.use_local_charts ? "" : local.mina_helm_repo
  chart      = var.use_local_charts ? "../../../../helm/seed-node" : "seed-node"
  version    = "1.0.11"
  namespace  = kubernetes_namespace.testnet_namespace.metadata[0].name
  values = [
    yamlencode(local.seed_vars)
  ]
  wait    = false
  timeout = 600
  depends_on = [
    kubernetes_role_binding.helm_release
  ]
}

# Block Producer

resource "helm_release" "block_producers" {
  provider = helm.testnet_deploy
  count    = length(local.block_producer_vars.blockProducerConfigs) > 0 ? 1 : 0

  name       = "${var.testnet_name}-block-producers"
  repository = var.use_local_charts ? "" : local.mina_helm_repo
  chart      = var.use_local_charts ? "../../../../helm/block-producer" : "block-producer"
  version    = "1.0.10"
  namespace  = kubernetes_namespace.testnet_namespace.metadata[0].name
  values = [
    yamlencode(local.block_producer_vars)
  ]
  wait       = false
  timeout    = 600
  depends_on = [helm_release.seeds]
}

# Plain nodes

resource "helm_release" "plain_nodes" {
  provider = helm.testnet_deploy
  count    = length(local.plain_node_vars)
  name       = "${var.testnet_name}-plain-node-${count.index + 1}"
  repository = var.use_local_charts ? "" : local.mina_helm_repo
  chart      = var.use_local_charts ? "../../../../helm/plain-node" : "plain-node"
  version    = "1.0.6"
  namespace  = kubernetes_namespace.testnet_namespace.metadata[0].name
  values = [
    yamlencode(local.plain_node_vars[count.index])
  ]
  wait       = false
  timeout    = 600
  depends_on = [helm_release.seeds]
}

# Snark Worker
resource "helm_release" "snark_workers" {
  provider = helm.testnet_deploy
  count    = length(local.snark_vars)

  name       = "${var.testnet_name}-snark-set-${count.index + 1}"
  repository = var.use_local_charts ? "" : local.mina_helm_repo
  chart      = var.use_local_charts ? "../../../../helm/snark-worker" : "snark-worker"
  version    = "1.0.9"
  namespace  = kubernetes_namespace.testnet_namespace.metadata[0].name
  values = [
    yamlencode(local.snark_vars[count.index])
  ]
  wait       = false
  timeout    = 600
  depends_on = [helm_release.seeds]
}

# Archive Node

resource "helm_release" "archive_node" {
  provider = helm.testnet_deploy
  count    = length(local.archive_vars)

  name       = "archive-${count.index + 1}"
  repository = var.use_local_charts ? "" : local.mina_helm_repo
  chart      = var.use_local_charts ? "../../../../helm/archive-node" : "archive-node"
  version    = "1.1.2"
  namespace  = kubernetes_namespace.testnet_namespace.metadata[0].name
  values = [
    yamlencode(local.archive_vars[count.index])
  ]

  wait       = false
  timeout    = 600
  depends_on = [helm_release.seeds]
}

# Watchdog

resource "helm_release" "watchdog" {
  provider   = helm.testnet_deploy
  count      = var.deploy_watchdog ? 1 : 0

  name       = "${var.testnet_name}-watchdog"
  repository = var.use_local_charts ? "" : local.mina_helm_repo
  chart      = var.use_local_charts ? "../../../../helm/watchdog" : "watchdog"
  version    = "0.1.0"
  namespace  = kubernetes_namespace.testnet_namespace.metadata[0].name
  values = [
    yamlencode(local.watchdog_vars)
  ]
  wait       = false
  timeout    = 600
  depends_on = [helm_release.seeds]
}

