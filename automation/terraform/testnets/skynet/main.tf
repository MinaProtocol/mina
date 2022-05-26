terraform {
  required_version = ">=0.13"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=4.3.0" # version required to run Terraform on Mac with M1
    }
  }
  backend "gcs" {
    bucket = "o1labs-terraform"
    prefix = "skynet-testnet"
  }
}

provider "aws" {
  region = "us-west-2"
}

#provider "google" {
#  alias   = "google-us-east4"
#  project = "o1labs-192920"
#  region  = "us-east4"
#  zone    = "us-east4-b"
#}

#provider "google" {
#  alias   = "google-us-east1"
#  project = "o1labs-192920"
#  region  = "us-east1"
#  zone    = "us-east1-b"
#}

provider "google" {
  alias   = "google-us-central1"
  project = "o1labs-192920"
  region  = "us-central1"
  zone    = "us-central1-c"
}


variable "whale_count" {
  type = number

  description = "Number of online whales for the network to run"
  default     = 2
}

variable "fish_count" {
  type = number

  description = "Number of online fish for the network to run"
  default     = 2
}

variable "seed_count" {
  default     = 2
}

variable "plain_node_count" {
  default     = 0
}

locals {
  testnet_name = "skynet"
  mina_image = "minaprotocol/mina-daemon:latest"
  mina_archive_image = "minaprotocol/mina-archive:1.2.0beta5-feature-gossip-qa-ledger-8e15537-buster-devnet"
  seed_region = "us-central1"
  seed_zone = "us-central1-b"

  # replace with `make_report_discord_webhook_url = ""` if not in use (will fail if file not present)
  #make_report_discord_webhook_url = <<EOT
  #  ${file("../../../discord_webhook_url.txt")}
  #EOT
  make_report_discord_webhook_url = ""

  # replace with `make_report_accounts = ""` if not in use (will fail if file not present)
  # make_report_accounts = <<EOT
  #   ${file("../../../${local.testnet_name}-accounts.csv")}
  # EOT
  make_report_accounts = ""
}

module "skynet" {
  providers = {
    google = google.google-us-central1
  }

  source    = "../../modules/o1-testnet"

  artifact_path = abspath(path.module)

  cluster_name   = "coda-infra-central1"
  cluster_region = "us-central1"
  k8s_context    = "gke_o1labs-192920_us-central1_coda-infra-central1"
  testnet_name   = local.testnet_name

  mina_image         = local.mina_image
  mina_archive_image = local.mina_archive_image
  mina_agent_image   = "codaprotocol/coda-user-agent:0.1.8"
  mina_bots_image    = "codaprotocol/coda-bots:0.0.13-beta-1"
  mina_points_image  = "codaprotocol/coda-points-hack:32b.4"
  watchdog_image     = "gcr.io/o1labs-192920/watchdog:0.4.5"
  use_embedded_runtime_config = true

  archive_node_count  = 2
  mina_archive_schema = "https://raw.githubusercontent.com/MinaProtocol/mina/fd3980820fb82c7355af49462ffefe6718800b77/src/app/archive/create_schema.sql"

  archive_configs       = [
    {
      name = "archive-1"
      enableLocalDaemon = false
      enablePostgresDB  = true
      postgresHost      = "archive-1-postgresql"
    },
    {
      name = "archive-2"
      enableLocalDaemon = false
      enablePostgresDB  = true
      postgresHost      = "archive-1-postgresql"
    }
  ]

  mina_faucet_amount = "10000000000"
  mina_faucet_fee    = "100000000"

  agent_min_fee = "0.05"
  agent_max_fee = "0.1"
  agent_min_tx = "1"
  agent_max_tx = "1"
  agent_send_every_mins = "1"

  seed_zone   = local.seed_zone
  seed_region = local.seed_region

  log_level           = "Info"
  log_txn_pool_gossip = false

  block_producer_key_pass           = "naughty blue worm"
  block_producer_starting_host_port = 10501

  snark_coordinators = []

  whales= [
    for i in range(var.whale_count):{
      duplicates = 1
    }
  ]
  
  fishes= [
    for i in range(var.fish_count):{
      duplicates = 1
    }
  ]

  seed_count            = var.seed_count
  plain_node_count      = var.seed_count

  upload_blocks_to_gcloud         = false
  restart_nodes                   = false
  restart_nodes_every_mins        = "60"
  make_reports                    = true
  make_report_every_mins          = "5"
  make_report_discord_webhook_url = local.make_report_discord_webhook_url
  make_report_accounts            = local.make_report_accounts
  # seed_peers_url                  = "https://storage.googleapis.com/mina-seed-lists/mainnet_seeds.txt"
}

