module "kubernetes_testnet" {
  providers = { google = google.gke }
  source    = "../kubernetes/testnet"

  use_local_charts    = true
  expose_graphql      = var.deploy_graphql_ingress
  healthcheck_enabled = false
  deploy_watchdog     = false

  cluster_name   = var.cluster_name
  cluster_region = var.cluster_region
  k8s_context    = var.k8s_context
  testnet_name   = var.testnet_name

  mina_image         = var.mina_image
  use_custom_entrypoint = true
  custom_entrypoint = "/mina_daemon_puppeteer.py"
  mina_archive_image = var.mina_archive_image
  mina_agent_image   = var.mina_agent_image
  mina_bots_image    = var.mina_bots_image
  mina_points_image  = var.mina_points_image
  enable_working_dir_persitence = var.enable_working_dir_persitence
  log_level             = "Trace"
  log_snark_work_gossip = true

  #make sure everyone has the seed peer's multiaddress
  additional_peers = ["/dns4/seed.${var.testnet_name}/tcp/${local.seed_external_port}/p2p/12D3KooWCoGWacXE4FRwAX8VqhnWVKhz5TTEecWEuGmiNrDt2XLf"]
  runtime_config   = var.runtime_config

  seed_zone   = "us-west1-a"
  seed_region = "us-west1"
  seed_external_port = local.seed_external_port
  seed_configs = [local.seed_config]

  archive_configs = local.archive_node_configs

  log_precomputed_blocks = var.log_precomputed_blocks
  log_txn_pool_gossip = true

  archive_node_count   = var.archive_node_count

  snark_coordinators = var.snark_coordinator_config == null ? [] :[ 
    {
      snark_coordinator_name = var.snark_coordinator_config.name
      snark_worker_replicas = var.snark_coordinator_config.worker_nodes
      snark_worker_fee      = var.snark_worker_fee
      snark_worker_public_key = var.snark_coordinator_config.public_key
      snark_coordinators_host_port = local.snark_worker_host_port
      persist_working_dir = var.enable_working_dir_persitence
    }
  ]

  # block_producer_key_pass = "naughty blue worm"
  block_producer_configs  = [
    for index, config in var.block_producer_configs : {
      name                   = config.name
      # id                     = config.id
      class                  = "test",
      external_port          = local.block_producer_starting_host_port + index
      keypair_name     = config.keypair.keypair_name
      # private_key     = config.keypair.private_key
      # public_key     = config.keypair.public_key
      privkey_password     = config.keypair.privkey_password
      libp2p_secret          = config.libp2p_secret
      isolated               = false
      enable_gossip_flooding = false
      run_with_user_agent    = false
      run_with_bots          = false
      enable_peer_exchange   = true
      enableArchive          = var.archive_node_count > 0
      archiveAddress         = element(local.archive_node_names, index)
      persist_working_dir    = var.enable_working_dir_persitence
    }
  ]

  cpu_request = var.cpu_request
  mem_request= var.mem_request
  worker_cpu_request = var.worker_cpu_request
  worker_mem_request= var.worker_mem_request

  #we don't use plain nodes in the intg test
  plain_node_configs = []
}
