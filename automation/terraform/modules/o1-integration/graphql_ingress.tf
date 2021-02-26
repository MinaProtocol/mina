resource "kubernetes_ingress" "testnet_graphql_ingress" {
  depends_on = [
    module.kubernetes_testnet.testnet_namespace,
    # module.kubernetes_testnet.seeds_release,
    module.kubernetes_testnet.block_producers_release,
    module.kubernetes_testnet.seed_release
  ]

  metadata {
    name = "${var.testnet_name}-graphql-ingress"
    namespace = var.testnet_name
  }

  spec {
    dynamic "rule" {
      for_each = concat(
        # [helm_release.seed],
        # var.block_producer_configs, 
        ["seed"],
        [for config in var.block_producer_configs : config.name],
        # local.snark_coord_names
      )
      # for_each = var.block_producer_configs

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
  depends_on = [kubernetes_ingress.testnet_graphql_ingress]

  zone_id = var.aws_route53_zone_id
  name    = "*.${local.base_graphql_dns}"
  type    = "A"
  ttl     = "300"
  records = [kubernetes_ingress.testnet_graphql_ingress.status[0].load_balancer[0].ingress[0].ip]
}
