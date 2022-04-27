terraform {
  experiments = [module_variable_optional_attrs]
}

provider "google" {
  alias = "gke"
}

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

variable "artifact_path" {
  type    = string
  default = "/tmp"
}

variable "mina_image" {
  type    = string
  default = "gcr.io/o1labs-192920/mina-daemon:1.2.0beta8-5b35b27-devnet"
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

variable "mina_agent_image" {
  type    = string
  default = "codaprotocol/coda-user-agent:0.1.4"
}

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

variable "use_embedded_runtime_config" {
  type    = bool
  default = false
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
  type = string
}

# Seed Vars

variable "seed_port" {
  type    = string
  default = "10001"
}

variable "seed_region" {
  type    = string
  default = "us-west1"
}

variable "seed_zone" {
  type    = string
  default = "us-west1-a"
}

variable "seed_discovery_keypairs" {
  type = list(any)
  default = [
    "CAESQNf7ldToowe604aFXdZ76GqW/XVlDmnXmBT+otorvIekBmBaDWu/6ZwYkZzqfr+3IrEh6FLbHQ3VSmubV9I9Kpc=,CAESIAZgWg1rv+mcGJGc6n6/tyKxIehS2x0N1Uprm1fSPSqX,12D3KooWAFFq2yEQFFzhU5dt64AWqawRuomG9hL8rSmm5vxhAsgr",
    "CAESQKtOnmYHQacRpNvBZDrGLFw/tVB7V4I14Y2xtGcp1sEsEyfcsNoFi7NnUX0T2lQDGQ31KvJRXJ+u/f9JQhJmLsI=,CAESIBMn3LDaBYuzZ1F9E9pUAxkN9SryUVyfrv3/SUISZi7C,12D3KooWB79AmjiywL1kMGeKHizFNQE9naThM2ooHgwFcUzt6Yt1"
  ]
}

# Block Producer Vars

variable "whales" {
  description = "individual whale block producer node deployment configurations"
  default = null
}

variable "fishes" {
  description = "individual fish block producer node deployment configurations"
  default = null
}

variable "nodes_with_user_agent" {
  type = list(string)
  default = []
}

variable "seed_count" {
  type    = number
  default = 1
}

variable "plain_node_count" {
  type    = number
  default = 1
}

variable "log_level" {
  type    = string
  default = "Trace"
}

variable "log_snark_work_gossip" {
  type    = bool
  default = false
}

variable "log_txn_pool_gossip" {
  type    = bool
  default = false
}

variable "block_producer_key_pass" {
  type = string
}

variable "block_producer_starting_host_port" {
  type    = number
  default = 10000
}

variable "seed_starting_host_port" {
  type    = number
  default = 10000
}

# Snark Worker Vars

variable "snark_coordinators" {
  description = "configurations for not just the snark coordinators but also the snark workers they coordinate"
  type    = list(any)
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

variable "log_precomputed_blocks" {
  type = bool
  default = false
}

# Archive-Postgres Vars

variable "archive_node_count" {
  type    = number
  default = 0
}

variable "archive_configs" {
  description = "individual archive-node deployment configurations"
  default = null
}

variable "upload_blocks_to_gcloud" {
  type    = bool
  default = false
}

variable "seed_peers_url" {
  type    = string
  default = ""
}
