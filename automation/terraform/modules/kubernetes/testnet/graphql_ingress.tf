resource "kubernetes_ingress" "testnet_graphql_ingress" {
  count = var.deploy_graphql_ingress ? 1 : 0
  depends_on = [kubernetes_namespace.testnet_namespace]

  metadata {
    name = "${var.testnet_name}-graphql-ingress"
    namespace = var.testnet_name
  }

  spec {
    dynamic "rule" {
      # for_each = concat(
      #   [helm_release.seed],
      #   var.block_producer_configs
      # )
      for_each = var.block_producer_configs

      content {
        http {
          path {
            backend {
              service_name = "${rule.value.name}-graphql"
              service_port = 3085
            }

            path = "/${rule.value.name}/*"
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
  name    = "${var.testnet_name}.graphql.o1test.net"
  type    = "A"
  ttl     = "300"
  records = [kubernetes_ingress.testnet_graphql_ingress[0].status[0].load_balancer[0].ingress[0].ip]
}
