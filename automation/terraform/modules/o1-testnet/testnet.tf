module "kubernetes_testnet" {
  providers = { google = google.gke }
  source    = "../kubernetes/testnet"

  cluster_name   = var.cluster_name
  cluster_region = var.cluster_region
  k8s_context    = var.k8s_context
  testnet_name   = var.testnet_name

  coda_image         = var.coda_image
  coda_archive_image = var.coda_archive_image
  coda_agent_image   = var.coda_agent_image
  coda_bots_image    = var.coda_bots_image
  coda_points_image  = var.coda_points_image

  coda_faucet_amount = var.coda_faucet_amount
  coda_faucet_fee    = var.coda_faucet_amount

  log_level           = var.log_level
  log_txn_pool_gossip = var.log_txn_pool_gossip

  agent_min_fee         = var.agent_min_fee
  agent_max_fee         = var.agent_max_fee
  agent_min_tx          = var.agent_min_tx
  agent_max_tx          = var.agent_max_tx
  agent_send_every_mins = var.agent_send_every_mins

  additional_peers = [for peer in values(local.static_peers) : peer.full_peer]
  runtime_config   = data.local_file.genesis_ledger.content

  seed_zone   = var.seed_zone
  seed_region = var.seed_region

  archive_node_count  = var.archive_node_count
  mina_archive_schema = var.mina_archive_schema

  snark_worker_replicas   = var.snark_worker_replicas
  snark_worker_fee        = var.snark_worker_fee
  snark_worker_public_key = var.snark_worker_public_key
  snark_worker_host_port  = var.snark_worker_host_port

  block_producer_key_pass = var.block_producer_key_pass
  block_producer_configs  = concat(
    [
      for i in range(var.whale_count): {
        name                   = local.whale_block_producer_names[i]
        class                  = "whale"
        id                     = i + 1
        external_port          = local.static_peers[local.whale_block_producer_names[i]].port
        private_key_secret     = "online-whale-account-${i + 1}-key"
        libp2p_secret          = "online-whale-libp2p-${i + 1}-key"
        enable_gossip_flooding = false
        run_with_user_agent    = false
        run_with_bots          = false
        enable_peer_exchange   = true
        isolated               = false
      }
    ],
    [
      for i in range(var.fish_count): {
        name                   = local.fish_block_producer_names[i]
        class                  = "fish"
        id                     = i + 1
        external_port          = local.static_peers[local.fish_block_producer_names[i]].port
        private_key_secret     = "online-fish-account-${i + 1}-key"
        libp2p_secret          = "online-fish-libp2p-${i + 1}-key"
        enable_gossip_flooding = false
        run_with_user_agent    = true
        run_with_bots          = false
        enable_peer_exchange   = true
        isolated               = false
      }
    ]
  )
}
