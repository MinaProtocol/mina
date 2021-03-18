resource "kubernetes_ingress" "testnet_graphql_ingress" {
  count = var.deploy_graphql_ingress ? 1 : 0
  depends_on = [
    module.kubernetes_testnet.testnet_namespace,
    module.kubernetes_testnet.seeds_release,
    module.kubernetes_testnet.block_producers_release,
    module.kubernetes_testnet.snark_workers_release
  ]

  metadata {
    name = "${var.testnet_name}-graphql-ingress"
    namespace = var.testnet_name
  }

  spec {
    dynamic "rule" {
      for_each = concat(
        [local.seed_config.name],
        [for config in var.block_producer_configs : config.name],
        var.snark_worker_replicas > 0 ? [local.snark_coordinator_name] : []
      )

      content {
        host = "${rule.value}.${local.base_graphql_dns}"
        http {
          path {
            backend {
              service_name = "${rule.value}-graphql"
              service_port = 3085
            }

            path = "/graphql"
          }
        }
      }
    }
  }

  wait_for_load_balancer = true
}

resource "aws_route53_record" "testnet_graphql_dns" {
  count = var.deploy_graphql_ingress ? 1 : 0
  depends_on = [kubernetes_ingress.testnet_graphql_ingress]

  zone_id = var.aws_route53_zone_id
  name    = "*.${local.base_graphql_dns}"
  type    = "A"
  ttl     = "300"
  records = [kubernetes_ingress.testnet_graphql_ingress[0].status[0].load_balancer[0].ingress[0].ip]
}
