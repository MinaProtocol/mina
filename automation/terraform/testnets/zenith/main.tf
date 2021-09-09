terraform {
  required_version = ">= 0.12.0"
  backend "s3" {
    key     = "terraform-zenith.tfstate"
    encrypt = true
    region  = "us-west-2"
    bucket  = "o1labs-terraform-state"
    acl     = "bucket-owner-full-control"
  }
}

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


variable "whale_count" {
  type = number

  description = "Number of online whales for the network to run"
  default     = 0
}

variable "fish_count" {
  type = number

  description = "Number of online fish for the network to run"
  default     = 0
}

variable "seed_count" {
  default     = 5
}

locals {
  testnet_name = "zenith"
  coda_image = "gcr.io/o1labs-192920/coda-daemon-baked:0.4.2-245a3f7-zenith-7a89538"
  coda_archive_image = "gcr.io/o1labs-192920/coda-archive:0.4.2-245a3f7"
  seed_region = "us-east4"
  seed_zone = "us-east4-b"

  # replace with `make_report_discord_webhook_url = ""` if not in use (will fail if file not present)
  make_report_discord_webhook_url = <<EOT
    ${file("../../../discord_webhook_url.txt")}
  EOT

  # replace with `make_report_accounts = ""` if not in use (will fail if file not present)
  # make_report_accounts = <<EOT
  #   ${file("../../../${local.testnet_name}-accounts.csv")}
  # EOT
  make_report_accounts = ""
}

module "testnet_east" {
  providers = { google.gke = google.google-us-east4 }
  source    = "../../modules/o1-testnet"

  artifact_path = abspath(path.module)

  cluster_name   = "coda-infra-east4"
  cluster_region = "us-east4"
  k8s_context    = "gke_o1labs-192920_us-east4_coda-infra-east4"
  testnet_name   = local.testnet_name

  coda_image         = local.coda_image
  coda_archive_image = local.coda_archive_image
  coda_agent_image   = "codaprotocol/coda-user-agent:0.1.8"
  coda_bots_image    = "codaprotocol/coda-bots:0.0.13-beta-1"
  coda_points_image  = "codaprotocol/coda-points-hack:32b.4"
  watchdog_image     = "gcr.io/o1labs-192920/watchdog:0.3.9"

  coda_faucet_amount = "10000000000"
  coda_faucet_fee    = "100000000"

  agent_min_fee = "0.05"
  agent_max_fee = "0.1"
  agent_min_tx = "0.0015"
  agent_max_tx = "0.0015"
  agent_send_every_mins = "1"

  archive_node_count  = 1
  mina_archive_schema = "https://raw.githubusercontent.com/MinaProtocol/mina/474e314bf6a35adb4976ed7c5b1b68f5c776ad78/src/app/archive/create_schema.sql" 

  seed_zone   = local.seed_zone
  seed_region = local.seed_region

  log_level           = "Info"
  log_txn_pool_gossip = false

  block_producer_key_pass           = "naughty blue worm"
  block_producer_starting_host_port = 10501

  snark_worker_replicas = 0
  snark_worker_fee      = "0.025"
  snark_worker_public_key = "B62qk4nuKn2U5kb4dnZiUwXeRNtP1LncekdAKddnd1Ze8cWZnjWpmMU"
  snark_worker_host_port = 10401
  whale_count           = var.whale_count
  fish_count            = var.fish_count
  seed_count            = var.seed_count

  upload_blocks_to_gcloud         = true
  restart_nodes                   = false
  restart_nodes_every_mins        = "60"
  make_reports                    = true
  make_report_every_mins          = "5"
  make_report_discord_webhook_url = local.make_report_discord_webhook_url
  make_report_accounts            = local.make_report_accounts
  seed_peers_url                  = "https://storage.googleapis.com/seed-lists/zenith_seeds.txt?123"
}
