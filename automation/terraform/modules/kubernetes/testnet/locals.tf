provider "helm" {
  alias = "testnet_deploy"
  kubernetes {
    config_context = var.k8s_context
  }
}

locals {
  mina_helm_repo = "https://coda-charts.storage.googleapis.com"

  # peers = var.additional_peers

  healthcheck_vars = {
    enabled             = var.healthcheck_enabled
    failureThreshold    = 60
    periodSeconds       = 5
    initialDelaySeconds = 30
  }

  seed_vars = {
    testnetName = var.testnet_name
    mina = {
      runtimeConfig = var.runtime_config
      image         = var.mina_image
      useCustomEntrypoint  = var.use_custom_entrypoint
      customEntrypoint     = var.custom_entrypoint
      // TODO: Change this to a better name
      seedPeers          = var.additional_peers
      logLevel           = var.log_level
      logSnarkWorkGossip = var.log_snark_work_gossip
      logTxnPoolGossip = var.log_txn_pool_gossip
      ports = {
        client  = "8301"
        graphql = "3085"
        metrics = "8081"
        p2p     = var.seed_external_port
      }
      # seedPeersURL         = var.seed_peers_url
      uploadBlocksToGCloud = var.upload_blocks_to_gcloud
      exposeGraphql        = var.expose_graphql
    }
    
    persist_working_dir = var.enable_working_dir_persitence

    seedConfigs = [
      for index, config in var.seed_configs : {
        name             = config.name
        class            = config.class
        libp2pSecret     = config.libp2p_secret
        libp2pSecretPassword = config.libp2p_secret_pw
        # privateKeySecret = config.private_key_secret
        # externalPort     = config.external_port
        externalIp       = config.external_ip
        enableArchive    = config.enableArchive
        archiveAddress   = config.archiveAddress
      }
    ]

    healthcheck = local.healthcheck_vars

  }

  daemon = {
    runtimeConfig        = var.runtime_config
    image                = var.mina_image
    useCustomEntrypoint  = var.use_custom_entrypoint
    customEntrypoint     = var.custom_entrypoint
    # privkeyPass          = var.block_producer_key_pass
    seedPeers            = var.additional_peers
    logLevel             = var.log_level
    logSnarkWorkGossip   = var.log_snark_work_gossip
    logPrecomputedBlocks = var.log_precomputed_blocks
    logTxnPoolGossip = var.log_txn_pool_gossip
    uploadBlocksToGCloud = var.upload_blocks_to_gcloud
    # seedPeersURL         = var.seed_peers_url
    exposeGraphql        = var.expose_graphql
    cpuRequest = var.cpu_request
    memRequest= var.mem_request
  }

  block_producer_vars = {
    testnetName = var.testnet_name

    mina = local.daemon

    healthcheck = local.healthcheck_vars

    userAgent = {
      image         = var.mina_agent_image
      minFee        = var.agent_min_fee
      maxFee        = var.agent_max_fee
      minTx         = var.agent_min_tx
      maxTx         = var.agent_max_tx
      txBatchSize   = var.agent_tx_batch_size
      sendEveryMins = var.agent_send_every_mins
      ports         = { metrics : 8000 }
    }

    bots = {
      image = var.mina_bots_image
      faucet = {
        amount = var.mina_faucet_amount
        fee    = var.mina_faucet_fee
      }
    }

    blockProducerConfigs = [
      for index, config in var.block_producer_configs : {
        name                 = config.name
        class                = config.class
        externalPort         = config.external_port
        runWithUserAgent     = config.run_with_user_agent
        runWithBots          = config.run_with_bots
        enableGossipFlooding = config.enable_gossip_flooding
        keypairName = config.keypair_name
        # privateKey     = config.private_key
        # publicKey     = config.private_key
        privateKeyPW     = config.privkey_password
        libp2pSecret         = config.libp2p_secret
        enablePeerExchange   = config.enable_peer_exchange
        isolated             = config.isolated
        enableArchive        = config.enableArchive
        archiveAddress       = config.archiveAddress
      }
    ]
    persist_working_dir = var.enable_working_dir_persitence
  }

  archive_vars = [for item in var.archive_configs : {
    testnetName = var.testnet_name
    mina        = {
      image         = var.mina_image
      useCustomEntrypoint  = var.use_custom_entrypoint
      customEntrypoint     = var.custom_entrypoint
      seedPeers     = var.additional_peers
      runtimeConfig = var.runtime_config
      # seedPeersURL  = var.seed_peers_url
    }
    healthcheck = local.healthcheck_vars
    archive     = item
    postgresql = {
      persistence = {
        enabled      = item["persistenceEnabled"]
        size         = item["persistenceSize"]
        storageClass = item["persistenceStorageClass"]
        accessModes  = item["persistenceAccessModes"]
      }
      primary = {
        affinity = {
          nodeAffinity = {
            requiredDuringSchedulingIgnoredDuringExecution = {
              nodeSelectorTerms = [
                {
                  matchExpressions = [
                    {
                      key = "cloud.google.com/gke-spot"
                      operator = item["spotAllowed"] ? "In" : "NotIn"
                      values = ["true"]
                    }
                  ]
                }
              ]
            }
          }
        }
      }
    }
    persist_working_dir = var.enable_working_dir_persitence
  }]

  snark_vars = [
    for i, snark in var.snark_coordinators: {
      testnetName = var.testnet_name
      mina        = local.daemon
      healthcheck = local.healthcheck_vars

      # coordinatorName = "snark-coordinator-${lower(substr(snark.snark_worker_public_key,-6,-1))}"
      coordinatorName = snark.snark_coordinator_name
      # workerName = "snark-worker-${lower(substr(snark.snark_worker_public_key,-6,-1))}"
      workerName = "${snark.snark_coordinator_name}-worker"
      workerReplicas = snark.snark_worker_replicas
      coordinatorHostName = "${snark.snark_coordinator_name}.${var.testnet_name}"
      coordinatorRpcPort = 8301
      coordinatorHostPort = snark.snark_coordinators_host_port
      publicKey = snark.snark_worker_public_key
      snarkFee = snark.snark_worker_fee
      workSelectionAlgorithm = "seq"

      workerCpuRequest    = var.worker_cpu_request
      workerMemRequest    = var.worker_mem_request
      persist_working_dir = var.enable_working_dir_persitence
    }
  ]

  plain_node_vars = [
    for i, node in var.plain_node_configs: {
      testnetName = var.testnet_name
      mina        = local.daemon
      healthcheck = local.healthcheck_vars
      name = node.name
      persist_working_dir = var.enable_working_dir_persitence
    }
  ]

  watchdog_vars = {
    testnetName = var.testnet_name
    image       = var.watchdog_image
    mina = {
      image                = var.mina_image
      ports                = { metrics : 8000 }
      uploadBlocksToGCloud = var.upload_blocks_to_gcloud
    }
    restartEveryMins            = var.restart_nodes_every_mins
    restartNodes                = var.restart_nodes
    makeReports                 = var.make_reports
    makeReportEveryMins         = var.make_report_every_mins
    makeReportDiscordWebhookUrl = var.make_report_discord_webhook_url
    makeReportAccounts          = var.make_report_accounts
    seedPeersURL                = var.additional_peers
  }
}
