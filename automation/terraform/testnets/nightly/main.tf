terraform {
  required_version = ">= 0.12.0"
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

variable "testnet_name" {
  type = string

  description = "Name identifier of testnet to provision"
  default     = "ci-net"
}

variable "mina_image" {
  type = string

  description = "Mina daemon image to use in provisioning a ci-net"
  default     = "gcr.io/o1labs-192920/coda-daemon:0.0.17-beta6-develop-0344dd5"
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

variable "mina_archive_image" {
  type = string

  description = "Mina archive node image to use in provisioning a ci-net"
  default     = "gcr.io/o1labs-192920/coda-archive:0.1.0-beta1-develop"
}

locals {
  seed_region = "us-east4"
  seed_zone = "us-east4-b"
  seed_discovery_keypairs = [
  "CAESQBEHe2zCcQDHcSaeIydGggamzmTapdCS8SP0hb5FWvYhe9XEygmlUGV4zNu2P8zAIba4X84Gm4usQFLamjRywA8=,CAESIHvVxMoJpVBleMzbtj/MwCG2uF/OBpuLrEBS2po0csAP,12D3KooWJ9mNdbUXUpUNeMnejRumKzmQF15YeWwAPAhTAWB6dhiv",
  "CAESQO+8qvMqTaQEX9uh4NnNoyOy4Xwv3U80jAsWweQ1J37AVgx7kgs4pPVSBzlP7NDANP1qvSvEPOTh2atbMMUO8EQ=,CAESIFYMe5ILOKT1Ugc5T+zQwDT9ar0rxDzk4dmrWzDFDvBE,12D3KooWFcGGeUmbmCNq51NBdGvCWjiyefdNZbDXADMK5CDwNRm5" ]
}

module "ci_testnet" {
  providers = { google.gke = google.google-us-east4 }
  source    = "../../modules/o1-testnet"


  cluster_name          = "coda-infra-east4"
  cluster_region        = "us-east4"
  k8s_context           = "gke_o1labs-192920_us-east4_coda-infra-east4"
  testnet_name          = var.testnet_name

  mina_image            = var.mina_image
  mina_archive_image    = var.mina_archive_image
  mina_agent_image      = "codaprotocol/coda-user-agent:0.1.5"
  mina_bots_image       = "codaprotocol/coda-bots:0.0.13-beta-1"
  mina_points_image     = "codaprotocol/coda-points-hack:32b.4"

  coda_faucet_amount    = "10000000000"
  coda_faucet_fee       = "100000000"

  agent_min_fee         = "0.05"
  agent_max_fee         = "0.1"
  agent_min_tx          = "0.0015"
  agent_max_tx          = "0.0015"
  agent_send_every_mins = "1"

  archive_node_count  = 0
  mina_archive_schema = "create_schema.sql"
  mina_archive_schema_aux_files = ["https://raw.githubusercontent.com/MinaProtocol/mina/develop/src/app/archive/create_schema.sql", "https://raw.githubusercontent.com/MinaProtocol/mina/develop/src/app/archive/snapp_tables.sql"]

  seed_zone   = local.seed_zone
  seed_region = local.seed_region

  log_level           = "Info"
  log_txn_pool_gossip = false

  block_producer_key_pass           = "naughty blue worm"
  block_producer_starting_host_port = 10501

  snark_coordinators = [
    {
      snark_worker_replicas   = 1
      snark_worker_fee        = "0.025"
      snark_worker_public_key = "B62qk4nuKn2U5kb4dnZiUwXeRNtP1LncekdAKddnd1Ze8cWZnjWpmMU"
      snark_coordinators_host_port  = 10401
    }
  ]
  
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
  plain_node_count = 0

}
