terraform {
  required_version = "~> 0.12.0"
  backend "s3" {
    key     = "terraform-bugspray.tfstate"
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
  alias   = "google-us-east1"
  project = "o1labs-192920"
  region  = "us-east1"
  zone    = "us-east1-b"
}

module "testnet_east" {
  providers = { google = google.google-us-east1 }
  source    = "../../modules/kubernetes/testnet"

  cluster_name          = "coda-infra-east"
  cluster_region        = "us-east1"
  testnet_name          = "pancake"

  coda_image            = "codaprotocol/coda-daemon:0.0.12-beta-develop-f1c2b80"
  coda_agent_image      = "codaprotocol/coda-user-agent:0.1.5"
  coda_bots_image       = "codaprotocol/coda-bots:0.0.13-beta-1"
  coda_points_image     = "codaprotocol/coda-points-hack:32b.4"

  coda_faucet_amount    = "10000000000"
  coda_faucet_fee       = "100000000"

  runtime_config = <<EOT
    {
      "daemon": {},
      "genesis": { 
        "genesis_state_timestamp": "${timestamp()}",
        "k": 20, 
        "delta": 3
      },
      "proof": {
        "c": 8
      },
      "ledger": ${file("../../../scripts/genesis_ledger.json")}
    }
  EOT

  seed_zone = "us-east1-b"
  seed_region = "us-east1"

  log_level              = "Trace"
  log_txn_pool_gossip    = true

  block_producer_key_pass = "naughty blue worm"
  block_producer_starting_host_port = 10001

  block_producer_configs = concat(
    [
      for i in range(5): {
        name                   = "whale-block-producer-${i + 1}"
        class                  = "whale"
        id                     = i + 1
        private_key_secret     = "online-whale-account-${i + 1}-key"
        enable_gossip_flooding = false
        run_with_user_agent    = false
        run_with_bots          = false
      }
    ],
    [
      for i in range(10): {
        name                   = "fish-block-producer-${i + 1}"
        class                  = "fish"
        id                     = i + 1
        private_key_secret     = "online-fish-account-${i + 1}-key"
        enable_gossip_flooding = false
        run_with_user_agent    = true
        run_with_bots          = false
      }
    ]
  )

  snark_worker_replicas = 8
  snark_worker_fee      = "0.025"
  snark_worker_public_key = "4vsRCVQZ41uqXfVVfkBNUuNNS7PgSJGdMDNAyKGDdU1WkdxxyxQ7oMdFcjDRf45fiGKkdYKkLPBrE1KnxmyBuvaTW97A5C8XjNSiJmvo9oHa4AwyVsZ3ACaspgQ3EyxQXk6uujaxzvQhbLDx"
  snark_worker_host_port = 10400

  agent_min_fee = "0.06"
  agent_max_fee = "0.1"
  agent_min_tx = "0.0015"
  agent_max_tx = "0.0015"
}
