output "seed_addresses" {
  value = local.seed_peers
}

output "testnet_namespace" {
  value = kubernetes_namespace.testnet_namespace
}
