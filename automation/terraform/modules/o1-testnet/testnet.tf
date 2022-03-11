resource "google_compute_address" "seed_static_ip" {
  count        = var.seed_count
  name         = "${var.testnet_name}-seed-static-ip-${count.index + 1}"
  address_type = "EXTERNAL"
  region       = var.cluster_region
  project      = "o1labs-192920"
}

data "aws_route53_zone" "selected" {
  name = "o1test.net."
}

resource "aws_route53_record" "seed_record" {
  count   = var.seed_count
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "seed-${count.index + 1}.${var.testnet_name}.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = [google_compute_address.seed_static_ip[count.index].address]
}

module "kubernetes_testnet" {
  providers = { google = google.gke }
  source    = "../kubernetes/testnet"

  cluster_name   = var.cluster_name
  cluster_region = var.cluster_region
  k8s_context    = var.k8s_context
  testnet_name   = var.testnet_name

  use_local_charts   = true
  mina_image         = var.mina_image
  mina_archive_image = var.mina_archive_image
  mina_agent_image   = var.mina_agent_image
  mina_bots_image    = var.mina_bots_image
  mina_points_image  = var.mina_points_image
  watchdog_image     = var.watchdog_image

  mina_faucet_amount = var.mina_faucet_amount
  mina_faucet_fee    = var.mina_faucet_fee

  log_level           = var.log_level
  log_txn_pool_gossip = var.log_txn_pool_gossip
  log_precomputed_blocks = var.log_precomputed_blocks

  agent_min_fee         = var.agent_min_fee
  agent_max_fee         = var.agent_max_fee
  agent_min_tx          = var.agent_min_tx
  agent_max_tx          = var.agent_max_tx
  agent_send_every_mins = var.agent_send_every_mins

  additional_peers = [for peer in local.static_peers : peer.full_peer]
  runtime_config   = var.use_embedded_runtime_config ? "" : data.local_file.genesis_ledger.content
  
  seed_zone   = var.seed_zone
  seed_region = var.seed_region

  archive_configs = local.archive_node_configs

  mina_archive_schema = var.mina_archive_schema
  mina_archive_schema_aux_files = var.mina_archive_schema_aux_files

  snark_coordinators = var.snark_coordinators

  block_producer_key_pass = var.block_producer_key_pass
  block_producer_configs = [for i, bp in local.block_producer_configs:
    {
      name                   = bp.name
      class                  = bp.class
      id                     = bp.total_node_index
      external_port          = bp.port
      private_key_secret     = "online-${bp.class}-account-${bp.unique_node_index}-key"
      libp2p_secret          = "online-${bp.class}-libp2p-${bp.total_node_index}-key"
      enable_gossip_flooding = false
      # run_with_user_agent    = bp.class =="whale" ? false : ( var.nodes_with_user_agent == [] ? true : contains(var.nodes_with_user_agent, bp.name) )
      run_with_user_agent = bp.class =="whale" ? false : true
      run_with_bots          = false
      enable_peer_exchange   = true
      isolated               = false
      enableArchive          = false
      archiveAddress         = length(local.archive_node_configs) != 0 ? "${element(local.archive_node_configs, i%(length(local.archive_node_configs)) )["name"]}:${element(local.archive_node_configs, i%(length(local.archive_node_configs)) )["serverPort"]}" : ""  
    }
  ]

  seed_configs = [
    for i in range(var.seed_count) : {
      name               = local.seed_static_peers[i].name
      class              = "seed"
      id                 = i + 1
      external_port      = local.seed_static_peers[i].port
      external_ip        = google_compute_address.seed_static_ip[i].address
      private_key_secret = "online-seeds-account-${i + 1}-key"
      libp2p_secret      = "online-seeds-libp2p-${i + 1}-key"
      enableArchive      = length(local.archive_node_configs) > 0
      archiveAddress     = length(local.archive_node_configs) > 0 ? "${element(local.archive_node_configs, i)["name"]}:${element(local.archive_node_configs, i)["serverPort"]}" : ""
    }
  ]

  plain_node_configs = [
    for i in range(var.plain_node_count) : {
      name               = "plain-node-${i+1}"
    }
  ]

  upload_blocks_to_gcloud         = var.upload_blocks_to_gcloud
  restart_nodes                   = var.restart_nodes
  restart_nodes_every_mins        = var.restart_nodes_every_mins
  make_reports                    = var.make_reports
  make_report_every_mins          = var.make_report_every_mins
  make_report_discord_webhook_url = var.make_report_discord_webhook_url
  make_report_accounts            = var.make_report_accounts
  seed_peers_url                  = var.seed_peers_url
}
