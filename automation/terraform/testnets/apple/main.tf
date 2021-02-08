terraform {
  required_version = "~> 0.14.5"
  backend "s3" {
    key     = "terraform-apple.tfstate"
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

module "apple_testnet" {
  providers = { google.gke = google.google-us-east4 }
  source    = "../../modules/o1-testnet"

  # TODO: remove obsolete cluster_name var + cluster region
  cluster_name   = "mina-integration-west1"
  cluster_region = "us-west1"
  k8s_context    = "gke_o1labs-192920_us-west1_mina-integration-west1"
  testnet_name   = "apple"

  coda_image         = "gcr.io/o1labs-192920/coda-daemon:0.2.11-develop"
  coda_archive_image = "gcr.io/o1labs-192920/coda-archive:0.2.11-develop"
  coda_agent_image   = "codaprotocol/coda-user-agent:0.1.8"
  coda_bots_image    = "codaprotocol/bots:1.0.0"
  coda_points_image  = "codaprotocol/coda-points-hack:32b.4"

  coda_faucet_amount = "10000000000"
  coda_faucet_fee    = "100000000"

  agent_min_fee = "0.05"
  agent_max_fee = "0.1"
  agent_min_tx = "0.0015"
  agent_max_tx = "0.0015"
  agent_send_every_mins = "1"

  archive_node_count  = 1
  mina_archive_schema = "https://raw.githubusercontent.com/MinaProtocol/mina/develop/src/app/archive/create_schema.sql"

  seed_zone   = "us-west1-b"
  seed_region = "us-west1"

  log_level           = "Info"
  log_txn_pool_gossip = false

  block_producer_key_pass           = "naughty blue worm"
  block_producer_starting_host_port = 10501

  snark_worker_replicas = 1
  snark_worker_fee      = "0.025"
  snark_worker_public_key = "B62qk4nuKn2U5kb4dnZiUwXeRNtP1LncekdAKddnd1Ze8cWZnjWpmMU"
  snark_worker_host_port = 10401

  whale_count = 1
  fish_count = 1
}
