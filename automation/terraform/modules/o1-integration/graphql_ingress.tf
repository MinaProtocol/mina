resource "kubernetes_ingress_v1" "testnet_graphql_ingress" {
  count = var.deploy_graphql_ingress ? 1 : 0
  depends_on = [
    module.kubernetes_testnet.testnet_namespace,
    module.kubernetes_testnet.seeds_release,
    module.kubernetes_testnet.block_producers_release,
    module.kubernetes_testnet.archive_nodes_release,
    module.kubernetes_testnet.snark_workers_release
  ]

  metadata {
    name = "${var.testnet_name}-graphql-ingress"
    namespace = var.testnet_name
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "nginx.org/mergeable-ingress-type" = "minion"
      "nginx.ingress.kubernetes.io/use-regex" = "true"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
    }
  }

  spec {
    rule {
      host = local.graphql_ingress_dns
      http {
        dynamic "path" {
          for_each = concat(
            [local.seed_config.name],
            [for config in var.block_producer_configs : config.name],
            [for config in var.archive_configs : config.name],
            var.snark_coordinator_config != null ? [var.snark_coordinator_config.name] : []
          )

          content {
            backend {
              service {
                name = "${path.value}-graphql"
                port {
                  number = 80
                }
              }
            }

            path = "/${path.value}(/|$)(.*)"
            path_type = "Prefix"
          }
        }
      }
    }
  }

  # wait_for_load_balancer = true
  wait_for_load_balancer = false
}
