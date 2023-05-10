# container build branch: fix/track3-genesis-ledger

#######################################
# terraform state location
#######################################

terraform {
  required_version = ">= 0.14.0"
  backend "s3" {
    key     = "terraform-itn3-testnet.tfstate"
    encrypt = true
    region  = "us-west-2"
    bucket  = "o1labs-terraform-state"
    acl     = "bucket-owner-full-control"
  }
}

#######################################
# cloud provider configs
#######################################

provider "aws" {
  region = "us-west-2"
}

provider "google" {
  alias   = "google-us-east4"
  project = "o1labs-192920"
  region  = "us-east4"
  zone    = "us-east4-b"
}

provider "google" {
  alias   = "google-us-east1"
  project = "o1labs-192920"
  region  = "us-east1"
  zone    = "us-east1-b"
}

provider "google" {
  alias   = "google-us-central1"
  project = "o1labs-192920"
  region  = "us-central1"
  zone    = "us-central1-c"
}

#######################################
# variable declarations
#######################################

variable "whale_count" {
  type    = number
  default = 0
}

variable "fish_count" {
  type    = number
  default = 3
}

#######################################
# node configurations
#######################################

module "node_configs" {
  providers      = { google.gke = google.google-us-central1 }
  source         = "../../modules/o1-testnet"
  cluster_name   = "coda-infra-central1"
  cluster_region = "us-central1"
  k8s_context    = "gke_o1labs-192920_us-central1_coda-infra-central1"

  testnet_name                = "testworld-2-0"
  artifact_path               = abspath(path.module)
  use_embedded_runtime_config = true

  mina_image         = "gcr.io/o1labs-192920/mina-daemon:2.0.0rampup2-fix-track3-genesis-ledger-9a9bacb-focal-berkeley"
  mina_archive_image = "gcr.io/o1labs-192920/mina-archive:2.0.0rampup2-fix-track3-genesis-ledger-9a9bacb-focal"
  mina_agent_image   = "codaprotocol/coda-user-agent:0.1.8"
  mina_bots_image    = "codaprotocol/coda-bots:0.0.13-beta-1"
  mina_points_image  = "codaprotocol/coda-points-hack:32b.4"
  watchdog_image     = "gcr.io/o1labs-192920/watchdog:0.4.3"

  # seed configs
  seed_count     = 3
  seed_zone      = "us-central1"
  seed_region    = "us-central1-b"
  seed_peers_url = "https://storage.googleapis.com/seed-lists/testworld-2-0_seeds.txt"

  # archive configs
  archive_node_count  = 3
  mina_archive_schema = "create_schema.sql"
  mina_archive_schema_aux_files = [
    "https://raw.githubusercontent.com/MinaProtocol/mina/9a9bacb6684f704bc7717e35bd6b446c73dc13ea/src/app/archive/create_schema.sql",
    "https://raw.githubusercontent.com/MinaProtocol/mina/9a9bacb6684f704bc7717e35bd6b446c73dc13ea/src/app/archive/zkapp_tables.sql"
  ]

  archive_configs = [
    {
      name              = "archive-1"
      enableLocalDaemon = true
      enablePostgresDB  = true
      postgresHost      = "archive-1-postgresql"
    },
    {
      name              = "archive-2"
      enableLocalDaemon = false
      enablePostgresDB  = false
      postgresHost      = "archive-1-postgresql"
    },
    {
      name              = "archive-3"
      enableLocalDaemon = false
      enablePostgresDB  = true
      postgresHost      = "archive-3-postgresql"
    }
  ]

  # snark worker configs
  snark_coordinators = [
    {
      snark_worker_replicas        = 2
      snark_worker_fee             = "0.01"
      snark_worker_public_key      = "B62qmQsEHcsPUs5xdtHKjEmWqqhUPRSF2GNmdguqnNvpEZpKftPC69e"
      snark_coordinators_host_port = 10401
    }
  ]

  worker_cpu_request = 4
  cpu_request        = 12
  worker_mem_request = "6Gi"
  mem_request        = "16Gi"

  # block producer configs
  block_producer_starting_host_port = 10501
  block_producer_key_pass           = "naughty blue worm"

  whales = [
    for i in range(var.whale_count) : { duplicates = 1 }
  ]

  fishes = [
    for i in range(var.fish_count) : { duplicates = 1 }
  ]

  # bot and agent configs
  mina_faucet_amount    = "10000000000"
  mina_faucet_fee       = "100000000"
  agent_min_fee         = "0.05"
  agent_max_fee         = "0.1"
  agent_min_tx          = "0.0015"
  agent_max_tx          = "0.0015"
  agent_send_every_mins = "1"

  # reporting configs
  log_level                       = "Debug"
  log_txn_pool_gossip             = false
  upload_blocks_to_gcloud         = true
  restart_nodes                   = false
  restart_nodes_every_mins        = "60"
  make_reports                    = true
  make_report_every_mins          = "5"
  make_report_discord_webhook_url = ""
  make_report_accounts            = ""
}
