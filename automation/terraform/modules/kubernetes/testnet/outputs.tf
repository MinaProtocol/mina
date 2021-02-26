output "testnet_namespace" {
  value = kubernetes_namespace.testnet_namespace
}

output "block_producers_release" {
  value = helm_release.block_producers
}

output "seed_release" {
  value = helm_release.seeds
}