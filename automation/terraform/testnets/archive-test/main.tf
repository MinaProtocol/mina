terraform {
  required_version = "~> 0.13.0"
  backend "s3" {
    key     = "terraform-archive-test.tfstate"
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

variable "coda_image" {
  type = string

  description = "Mina daemon image to use in provisioning a ci-net"
  default     = "gcr.io/o1labs-192920/coda-daemon-baked:0.1.1-41db206-archive-test-ff770fd"
}

variable "coda_archive_image" {
  type = string

  description = "Mina archive node image to use in provisioning a ci-net"
  default     = "gcr.io/o1labs-192920/coda-archive:0.3.3-add-dhall-job-step-condition-f4bbf61"
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
  default = 10
}

variable "ci_cluster_region" {
  type    = string
  default = "us-central1"
}

variable "ci_k8s_ctx" {
  type    = string
  default = "gke_o1labs-192920_us-central1_coda-infra-central1"
}

variable "ci_artifact_path" {
  type    = string
  default = "/tmp"
}

locals {
  seed_region = "us-central1"
  seed_zone = "us-central1-b"
  mina_archive_schema   = "https://raw.githubusercontent.com/MinaProtocol/mina/master/src/app/archive/create_schema.sql"
}


module "ci_testnet" {
  providers = { google = google.google-us-east4 }
  source    = "../../modules/o1-testnet"


  # TODO: remove obsolete cluster_name var + cluster region
  cluster_name          = "coda-infra-central1"
  cluster_region        = var.ci_cluster_region
  k8s_context           = var.ci_k8s_ctx
  testnet_name          = "archive-test"

  coda_image            = var.coda_image
  coda_archive_image    = var.coda_archive_image
  coda_agent_image      = "codaprotocol/coda-user-agent:0.1.8"
  coda_bots_image       = "codaprotocol/bots:1.0.0"
  coda_points_image     = "codaprotocol/coda-points-hack:32b.4"

  coda_faucet_amount    = "10000000000"
  coda_faucet_fee       = "100000000"

  archive_node_count    = var.archive_count
  mina_archive_schema   = local.mina_archive_schema


  seed_zone = local.seed_zone
  seed_region = local.seed_region

  log_level              = "Info"
  log_txn_pool_gossip    = false

  block_producer_key_pass = "naughty blue worm"
  block_producer_starting_host_port = 10501

  whale_count = var.whale_count
  fish_count = var.fish_count

  snark_worker_replicas = var.snark_worker_count
  snark_worker_fee      = "0.025"
  snark_worker_public_key = "B62qk4nuKn2U5kb4dnZiUwXeRNtP1LncekdAKddnd1Ze8cWZnjWpmMU"
  snark_worker_host_port = 10401

  agent_min_fee = "0.05"
  agent_max_fee = "0.1"
  agent_min_tx = "0.0015"
  agent_max_tx = "0.0015"
  agent_send_every_mins = "1"

  artifact_path = var.ci_artifact_path
}

