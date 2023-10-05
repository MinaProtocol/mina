terraform {
  required_version = ">= 0.14.0"
  backend "s3" {
    key     = "terraform-nightly.tfstate"
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

variable "whale_count" {
  type = number

  description = "Number of online whales for the network to run"
  default     = 1
}

variable "fish_count" {
  type = number

  description = "Number of online fish for the network to run"
  default     = 1
}

variable "seed_count" {
  default = 3
}

variable "plain_node_count" {
  default = 1
}


locals {
  testnet_name = "ci-net"
  seed_region  = "us-east4"
  seed_zone    = "us-east4-b"
  seed_discovery_keypairs = [
    "CAESQBEHe2zCcQDHcSaeIydGggamzmTapdCS8SP0hb5FWvYhe9XEygmlUGV4zNu2P8zAIba4X84Gm4usQFLamjRywA8=,CAESIHvVxMoJpVBleMzbtj/MwCG2uF/OBpuLrEBS2po0csAP,12D3KooWJ9mNdbUXUpUNeMnejRumKzmQF15YeWwAPAhTAWB6dhiv",
  "CAESQO+8qvMqTaQEX9uh4NnNoyOy4Xwv3U80jAsWweQ1J37AVgx7kgs4pPVSBzlP7NDANP1qvSvEPOTh2atbMMUO8EQ=,CAESIFYMe5ILOKT1Ugc5T+zQwDT9ar0rxDzk4dmrWzDFDvBE,12D3KooWFcGGeUmbmCNq51NBdGvCWjiyefdNZbDXADMK5CDwNRm5"]

  mina_image         = "gcr.io/o1labs-192920/mina-daemon:2.0.0rampup3-rampup-264bcac-focal-berkeley"
  mina_archive_image = "gcr.io/o1labs-192920/mina-archive:2.0.0rampup3-rampup-264bcac-focal"

  # replace with `make_report_discord_webhook_url = ""` if not in use (will fail if file not present)
  make_report_discord_webhook_url = ""

  # replace with `make_report_accounts = ""` if not in use (will fail if file not present)
  # make_report_accounts = <<EOT
  #   ${file("../../../${local.testnet_name}-accounts.csv")}
  # EOT
  make_report_accounts = ""
}

module "ci_testnet" {
  providers = { google.gke = google.google-us-east4 }
  source    = "../../modules/o1-testnet"

  artifact_path = abspath(path.module)

  cluster_name   = "coda-infra-east4"
  cluster_region = "us-east4"
  k8s_context    = "gke_o1labs-192920_us-east4_coda-infra-east4"
  testnet_name   = local.testnet_name

  mina_image         = local.mina_image
  mina_archive_image = local.mina_archive_image
  mina_agent_image   = "codaprotocol/coda-user-agent:0.1.5"
  mina_bots_image    = "codaprotocol/coda-bots:0.0.13-beta-1"
  mina_points_image  = "codaprotocol/coda-points-hack:32b.4"

  mina_faucet_amount = "10000000000"
  mina_faucet_fee    = "100000000"

  agent_min_fee         = "0.05"
  agent_max_fee         = "0.1"
  agent_min_tx          = "0.0015"
  agent_max_tx          = "0.0015"
  agent_send_every_mins = "1"

  archive_node_count            = 1
  mina_archive_schema           = "create_schema.sql"
  mina_archive_schema_aux_files = ["https://raw.githubusercontent.com/MinaProtocol/mina/berkeley/src/app/archive/create_schema.sql", "https://raw.githubusercontent.com/MinaProtocol/mina/berkeley/src/app/archive/zkapp_tables.sql"]

  archive_configs = [
    {
      name              = "archive-1"
      enableLocalDaemon = true
      enablePostgresDB  = true
      postgresHost      = "archive-1-postgresql"
    },
  ]

  seed_zone   = local.seed_zone
  seed_region = local.seed_region

  log_level           = "Info"
  log_txn_pool_gossip = false

  block_producer_key_pass           = "naughty blue worm"
  block_producer_starting_host_port = 10501

  worker_cpu_request = 4
  cpu_request        = 12
  worker_mem_request = "6Gi"
  mem_request        = "16Gi"

  snark_coordinators = [
    {
      snark_worker_replicas        = 1
      snark_worker_fee             = "0.025"
      snark_worker_public_key      = "B62qk4nuKn2U5kb4dnZiUwXeRNtP1LncekdAKddnd1Ze8cWZnjWpmMU"
      snark_coordinators_host_port = 10401
    }
  ]

  whales = [
    for i in range(var.whale_count) : {
      duplicates = 1
    }
  ]

  fishes = [
    for i in range(var.fish_count) : {
      duplicates = 1
    }
  ]
  plain_node_count = 0

  upload_blocks_to_gcloud         = true
  restart_nodes                   = false
  restart_nodes_every_mins        = "60"
  make_reports                    = true
  make_report_every_mins          = "5"
  make_report_discord_webhook_url = local.make_report_discord_webhook_url
  make_report_accounts            = local.make_report_accounts

}
