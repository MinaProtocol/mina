# terraform {
#   experiments = [module_variable_optional_attrs]
# }

# K8s Cluster Vars

variable "cluster_name" {
  type = string
}

variable "cluster_region" {
  type = string
}

variable "k8s_context" {
  type = string

  description = "K8s resource provider context"
  default     = "gke_o1labs-192920_us-east1_coda-infra-east"
}

# Global Vars

variable "expose_graphql" {
  type    = bool
  default = false
}

variable "use_local_charts" {
  type    = bool
  default = false
}

variable "healthcheck_enabled" {
  type    = bool
  default = true
}

variable "deploy_watchdog" {
  type    = bool
  default = true
}

variable "mina_image" {
  type    = string
  default = "gcr.io/o1labs-192920/mina-daemon:1.2.0beta8-5b35b27-devnet"
}

variable "use_custom_entrypoint" {
  type    = bool
  default = false
}

variable "custom_entrypoint" {
  type    = string
  default = ""
}

variable "mina_archive_image" {
  type    = string
  default = ""
}

variable "mina_archive_schema" {
  type    = string
  default = ""
}

variable "mina_archive_schema_aux_files" {
  type    = list(string)
  default = []
}

variable "archive_node_count" {
  type    = number
  default = 0
}

variable "mina_agent_image" {
  type    = string
  default = "codaprotocol/coda-user-agent:0.1.4"
}

#this var doesn't actually hook up to anything
variable "mina_agent_active" {
  type    = string
  default = "true"
}

variable "mina_bots_image" {
  type    = string
  default = ""
}

variable "mina_points_image" {
  type    = string
  default = ""
}

variable "watchdog_image" {
  type    = string
  default = "gcr.io/o1labs-192920/watchdog:latest"
}

# this must be a string to avoid scientific notation truncation
variable "mina_faucet_amount" {
  type    = string
  default = "10000000000"
}

# this must be a string to avoid scientific notation truncation
variable "mina_faucet_fee" {
  type    = string
  default = "100000000"
}

variable "testnet_name" {
  type    = string
  default = "mina-testnet"
}

variable "additional_peers" {
  type    = list(any)
  default = []
}

variable "runtime_config" {
  type    = string
  default = ""
}

variable "log_snark_work_gossip" {
  type    = bool
  default = false
}

variable "log_precomputed_blocks" {
  type    = bool
  default = false
}

variable "log_txn_pool_gossip" {
  type    = bool
  default = false
}

variable "cpu_request" {
  type    = number
  default = 0
}

variable "mem_request" {
  type    = string
  default = "0Mi"
}

# Seed Vars

variable "seed_region" {
  type    = string
  default = "us-west1"
}

variable "seed_zone" {
  type    = string
  default = "us-west1-a"
}

# variable "seed_discovery_keypairs" {
#   type = list(any)
#   default = [
#     "CAESQNf7ldToowe604aFXdZ76GqW/XVlDmnXmBT+otorvIekBmBaDWu/6ZwYkZzqfr+3IrEh6FLbHQ3VSmubV9I9Kpc=,CAESIAZgWg1rv+mcGJGc6n6/tyKxIehS2x0N1Uprm1fSPSqX,12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr",
#     "CAESQKtOnmYHQacRpNvBZDrGLFw/tVB7V4I14Y2xtGcp1sEsEyfcsNoFi7NnUX0T2lQDGQ31KvJRXJ+u/f9JQhJmLsI=,CAESIBMn3LDaBYuzZ1F9E9pUAxkN9SryUVyfrv3/SUISZi7C,12D3KooWB79AmjiywL1kMGeKHizFNQE9naThM2ooHgwFcUzt6Yt1"
#   ]
# }

variable "seed_external_port" {
  type    = string
  default = "10001"
}

variable "seed_configs" {
  type = list(
    object({
      name               = string,
      class              = string,
      libp2p_secret      = string,
      libp2p_secret_pw = string
      # external_port      = number,
      external_ip        = string,
      # private_key_secret = string,
      enableArchive      = bool,
      archiveAddress     = string
      persist_working_dir = bool,
    })
  )
  default = []
}

# Block Producer Vars

variable "log_level" {
  type    = string
  default = "Trace"
}

# variable "block_producer_key_pass" {
#   type = string
# }

variable "block_producer_configs" {
  type = list(
    object({
      name                   = string,
      class                  = string,
      keypair_name     = string,
      # private_key            = string,
      # public_key             = string,
      privkey_password = string,
      external_port          = number,
      libp2p_secret          = string,
      enable_gossip_flooding = bool,
      enable_peer_exchange   = bool,
      isolated               = bool,
      run_with_user_agent    = bool,
      run_with_bots          = bool,
      enableArchive          = bool,
      archiveAddress         = string
      persist_working_dir    = bool,
    })
  )
  default = []
}

variable "plain_node_configs" {
  default = null
}

# Snark Worker Vars
variable "snark_coordinators" {
  type    = list(    
    object({

      snark_coordinator_name = string,
      snark_worker_replicas = number
      snark_worker_fee      = number
      snark_worker_public_key = string
      snark_coordinators_host_port = number
      persist_working_dir = bool
    }))
  default = []
}

variable "agent_min_fee" {
  type    = string
  default = ""
}

variable "agent_max_fee" {
  type    = string
  default = ""
}

variable "agent_min_tx" {
  type    = string
  default = ""
}

variable "agent_max_tx" {
  type    = string
  default = ""
}

variable "agent_tx_batch_size" {
  type    = string
  default = ""
}

variable "agent_send_every_mins" {
  type    = string
  default = ""
}

variable "gcloud_seeds" {
  type    = list(any)
  default = []
}

variable "worker_cpu_request" {
  type    = number
  default = 0
}

variable "worker_mem_request" {
  type    = string
  default = "0Mi"
}

# Mina network services vars

variable "restart_nodes" {
  type    = bool
  default = true
}

variable "restart_nodes_every_mins" {
  type    = string
  default = "60"
}

variable "make_report_every_mins" {
  type    = string
  default = "30"
}

variable "make_reports" {
  type    = bool
  default = true
}

variable "make_report_discord_webhook_url" {
  type    = string
  default = ""
}

variable "make_report_accounts" {
  type    = string
  default = ""
}

# Archive | Postgres Vars

variable "archive_configs" {
  type = list(
    object({
      name                    = string
      image                   = string
      serverPort              = string
      externalPort            = string
      enableLocalDaemon       = bool
      enablePostgresDB        = bool

      postgresHost            = string
      postgresPort            = string
      remoteSchemaFile        = string
      remoteSchemaAuxFiles        = list(string)

      persistenceEnabled      = bool
      persistenceSize         = string
      persistenceStorageClass = string
      persistenceAccessModes  = list(string)
      spotAllowed             = string
      persist_working_dir     = bool
    })
  )
  default = []
}

variable "upload_blocks_to_gcloud" {
  type    = bool
  default = false
}

# variable "seed_peers_url" {
#   type    = string
#   default = ""
# }

variable "zkapps_dashboard_key" {
  type    = string
  default = ""
}


variable "enable_working_dir_persitence" {
  type    = bool
  default = false
}