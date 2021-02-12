resource "kubernetes_secret" "keypairs" {
  for_each = {for config in var.block_producer_configs : config.name => config}

  metadata {
    name      = each.value.keypair_secret
    namespace = var.testnet_name
  }

  data = {
    pub = each.value.public_key
    key = each.value.private_key
  }
}
