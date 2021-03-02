locals {
  base_graphql_dns = "${var.testnet_name}.graphql.o1test.net"
  snark_worker_host_port            = 10001
  block_producer_starting_host_port = 10010

  seed_peer = {
    multiaddr = "/dns4/seed.${var.testnet_name}/tcp/10401/p2p/12D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf",
    peerid = "2D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf",
    private_key_secretbox = "{\"box_primitive\":\"xsalsa20poly1305\",\"pw_primitive\":\"argon2i\",\"nonce\":\"7YSQmeRbo4fGd2nYh9aS4WzNWzSXsFmmkTqKy93\",\"pwsalt\":\"9QsEJdSkFbF8PUwLPo2ZLHpgT7ja\",\"pwdiff\":[134217728,6],\"ciphertext\":\"7o8WU4cBiuUqGPaF2fNA815XqhZM5j95dhns5zztCiSehb3xVzTUSbCj1nDXG5rAteu67pvMnaGbQ57cQw1HEPB2DDdrtAAWbCt7qYjmP6cNm2L7H9DC8NKHs1LYuWvthfjDvxBDHnVidpRCyqtMBg9TPWtMPkZy1UCVRFokAA5HaA2xkh4WFgy2SCVrAeWNP5BeUGq9u779KcM9BAtg9n6rqbKDTybX4h1aSZ9qA72tg1LHzENfHLAgzJXZQcxhjvw6b8H51m9rVhwFTKPCRRCNXfcyQqjEpH4fm\"}",
    secret = "seed-discovery-keys",
    port = 10401
  }

  seed_config = {
    name               = "seed",
    class              = "seed",
    libp2p_secret      = local.seed_peer.secret,
    external_port      = 10401,
    node_port          = null,
    external_ip        = null,
    private_key_secret = null,
    enableArchive      = false,
    archiveAddress     = null
  }

  snark_coordinator_name = "snark-coordinator-${lower(substr(var.snark_worker_public_key, length(var.snark_worker_public_key) - 6, 6))}"
}
