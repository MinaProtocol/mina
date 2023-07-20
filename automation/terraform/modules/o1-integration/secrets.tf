resource "kubernetes_secret" "mina_account_keypairs" {
  depends_on = [module.kubernetes_testnet.testnet_namespace]
  for_each   = { for config in var.block_producer_configs : config.name => config }

  metadata {
    name      = each.value.keypair.keypair_name
    namespace = var.testnet_name
  }

  data = {
    pub = each.value.keypair.public_key
    key = each.value.keypair.private_key
  }
}

#this is entire for the seed peer
resource "kubernetes_secret" "libp2p_discovery_keys" {
  depends_on = [module.kubernetes_testnet.testnet_namespace]

  metadata {
    name      = local.seed_config.libp2p_secret
    namespace = var.testnet_name
  }

  data = {
    key = "{\"box_primitive\":\"xsalsa20poly1305\",\"pw_primitive\":\"argon2i\",\"nonce\":\"7YSQmeRbo4fGd2nYh9aS4WzNWzSXsFmmkTqKy93\",\"pwsalt\":\"9QsEJdSkFbF8PUwLPo2ZLHpgT7ja\",\"pwdiff\":[134217728,6],\"ciphertext\":\"7o8WU4cBiuUqGPaF2fNA815XqhZM5j95dhns5zztCiSehb3xVzTUSbCj1nDXG5rAteu67pvMnaGbQ57cQw1HEPB2DDdrtAAWbCt7qYjmP6cNm2L7H9DC8NKHs1LYuWvthfjDvxBDHnVidpRCyqtMBg9TPWtMPkZy1UCVRFokAA5HaA2xkh4WFgy2SCVrAeWNP5BeUGq9u779KcM9BAtg9n6rqbKDTybX4h1aSZ9qA72tg1LHzENfHLAgzJXZQcxhjvw6b8H51m9rVhwFTKPCRRCNXfcyQqjEpH4fm\"}"
    pub = "12D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf" #this is also the peer-id
  }
}
