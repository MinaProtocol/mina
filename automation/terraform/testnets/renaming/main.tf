terraform {
  required_version = "~> 0.13.4"
  backend "s3" {
    key     = "terraform-renaming.tfstate"
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
  alias   = "google-us-west1"
  project = "o1labs-192920"
  region  = "us-west1"
  zone    = "us-west1-a"
}

variable "coda_image" {
  type = string

  description = "Mina daemon image to use in provisioning a ci-net"
  default     = "gcr.io/o1labs-192920/coda-daemon:0.4.2-renaming-mina-binary-and-mina-config-87e6365"
}

variable "coda_archive_image" {
  type = string

  description = "Mina archive node image to use in provisioning a ci-net"
  default     = "gcr.io/o1labs-192920/coda-archive:0.4.2-renaming-mina-binary-and-mina-config-87e6365"
}

variable "whale_count" {
  type    = number
  default = 5
}

variable "fish_count" {
  type    = number
  default = 5
}

variable "archive_count" {
  type    = number
  default = 1
}

variable "snark_worker_count" {
  type    = number
  default = 1
}

variable "ci_cluster_region" {
  type    = string
  default = "us-west1"
}

variable "ci_k8s_ctx" {
  type    = string
  default = "gke_o1labs-192920_us-west1_mina-integration-west1"
}

variable "ci_artifact_path" {
  type    = string
  default = "/tmp"
}

locals {
  seed_region = "us-west1"
  seed_zone = "us-west1-b"
}


module "ci_testnet" {
  providers = { google.gke = google.google-us-west1 }
  source    = "../../modules/o1-testnet"

  artifact_path = abspath(path.module)

  # TODO: remove obsolete cluster_name var + cluster region
  cluster_name          = "mina-integration-west1"
  cluster_region        = var.ci_cluster_region
  k8s_context           = var.ci_k8s_ctx
  testnet_name          = "renaming"

  coda_image            = var.coda_image
  coda_archive_image    = var.coda_archive_image
  coda_agent_image      = "codaprotocol/coda-user-agent:0.1.8"
  coda_bots_image       = "codaprotocol/bots:1.0.0"
  coda_points_image     = "codaprotocol/coda-points-hack:32b.4"

  coda_faucet_amount    = "10000000000"
  coda_faucet_fee       = "100000000"

  agent_min_fee = "0.05"
  agent_max_fee = "0.1"
  agent_min_tx = "0.0015"
  agent_max_tx = "0.0015"
  agent_send_every_mins = "1"

  archive_node_count    = var.archive_count
  mina_archive_schema   = "https://raw.githubusercontent.com/MinaProtocol/mina/develop/src/app/archive/create_schema.sql"

  seed_zone = local.seed_zone
  seed_region = local.seed_region

  log_level              = "Info"
  log_txn_pool_gossip    = false

  block_producer_key_pass = "naughty blue worm"
  block_producer_starting_host_port = 10501

  snark_worker_replicas = var.snark_worker_count
  snark_worker_fee      = "0.025"
  snark_worker_public_key = "B62qk4nuKn2U5kb4dnZiUwXeRNtP1LncekdAKddnd1Ze8cWZnjWpmMU"
  snark_worker_host_port = 10401

  whale_count = var.whale_count
  fish_count = var.fish_count
}
