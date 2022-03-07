terraform {
  required_version = ">= 0.14.0"
  backend "s3" {
    key     = "terraform-gossip-qa.tfstate"
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

  description = "Number of unique online whales for the network to run"
  default     = 18
}

variable "fish_count" {
  type = number

  description = "Number of unique online fish for the network to run"
  default     = 72
}

variable "seed_count" {
  default     = 3
}

variable "plain_node_count" {
  default     = 1
}

locals {
  testnet_name = "gossipqa"
  mina_image = "gcr.io/o1labs-192920/mina-daemon:1.2.0beta5-feature-gossip-qa-ledger-8e15537-buster-devnet"
  mina_archive_image = "minaprotocol/mina-archive:1.2.0beta5-feature-gossip-qa-ledger-8e15537-buster-devnet"
  seed_region = "us-central1"
  seed_zone = "us-central1-c"

  # replace with `make_report_discord_webhook_url = ""` if not in use (will fail if file not present)
  # make_report_discord_webhook_url = <<EOT
  #   ${file("../../../discord_webhook_url.txt")}
  # EOT
  make_report_discord_webhook_url = ""

  # replace with `make_report_accounts = ""` if not in use (will fail if file not present)
  # make_report_accounts = <<EOT
  #   ${file("../../../${local.testnet_name}-accounts.csv")}
  # EOT
  make_report_accounts = ""
}

module "gossipqa" {
  providers = { google.gke = google.google-us-central1 }
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
  watchdog_image     = "gcr.io/o1labs-192920/watchdog:0.4.3"
  use_embedded_runtime_config = true

  archive_node_count  = 3
  mina_archive_schema = "create_schema.sql"
  mina_archive_schema_aux_files = ["https://raw.githubusercontent.com/MinaProtocol/mina/develop/src/app/archive/create_schema.sql", "https://raw.githubusercontent.com/MinaProtocol/mina/develop/src/app/archive/snapp_tables.sql"]

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
      enablePostgresDB  = false
      postgresHost      = "archive-1-postgresql"
    },
    {
      name = "archive-3"
      enableLocalDaemon = false
      enablePostgresDB  = true
      postgresHost      = "archive-3-postgresql"
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

  snark_coordinators=[
# gotta manually change the public keys, get them from whatever genesis ledger we're running this with
# if we want to do this automatically, we would need to modify generate-keys-and-ledger.sh to create a separate batch of files with pulbic keys of all block producer nodes and read those in
    {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qjXQcUtWGb2YPnnP7YE9DxgXhAXgWTLdTjuYhXuXegEhXY6LQCj7"
      snark_coordinators_host_port = 10401
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qqfus8oqhNEAXdT9FhDXNfFW6SPJgfSSdbNTDaC8YbMmavD7V8z8"
      snark_coordinators_host_port = 10402
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qntfBJjRwhvTfvjXu3CDk4LUVqqGRhEs4qGQgwsFvmvcpnzBobBH"
      snark_coordinators_host_port = 10403
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qkJzX8LAfahyXKR3zZs9tiXy6aRCdz8yYKf1qyjV5VXV4kFfSazo"
      snark_coordinators_host_port = 10404
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qqe4rmDc3BCHmvDyt1bfPWabgu52Sr5xzq6KxZSFGSjdYb8YPcPW"
      snark_coordinators_host_port = 10405
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qnk8Ev9cVwtLASqDNmwqpjWsdyyCktkGXU6zTidxvYaddhJhoaXd"
      snark_coordinators_host_port = 10406
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qmNay4xNME4JYrb6r58rViE5FJkNkm681WWGau8ybbRuX37WAMXs"
      snark_coordinators_host_port = 10407
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qpd3VrJCoeK2Fh9CGYTLyjKJBaEHbSgTKzE5z3KnxRakU9b6mCKx"
      snark_coordinators_host_port = 10408
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qqrF37sCNCwwSdJnMxCfiDifKWnE8dxV7nqoaNYzB2furmbEWqo7"
      snark_coordinators_host_port = 10409
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qrD6iWkaUjP3yGLLLTLoV41zeUBEap6GrparAYNV8SuKnYaTLvqC"
      snark_coordinators_host_port = 10410
    }
  ]

  seed_count            = var.seed_count

  plain_node_count = var.plain_node_count

  # whales= [    
  #   {
  #     duplicates = 2
  #   },
  #   {
  #     duplicates = 1
  #   }
  # ]

  # fishes= [    
  #   {
  #     duplicates = 2
  #   },
  #   {
  #     duplicates = 1
  #   }
  # ]

  whales= concat( 
    [for i in range(var.whale_count/3):{
        duplicates = 3
        class  = "whale"
      }], 
    [for i in range(var.whale_count/3):{
        duplicates = 2
        class  = "whale"
      }], 
    [for i in range(var.whale_count/3):{
        duplicates = 1
        class  = "whale"
      }]
  )
  
  fishes=concat( 
    [for i in range(var.fish_count/3):{
        duplicates = 3
        class  = "fish"
      }], 
    [for i in range(var.fish_count/3):{
        duplicates = 2
        class  = "fish"
      }], 
    [for i in range(var.fish_count/3):{
        duplicates = 1
        class  = "fish"
      }]
  )

  nodes_with_user_agent = ["fish-1-1","fish-2-1", "fish-3-1", "fish-4-1", "fish-5-1", "fish-6-1", "fish-7-1", "fish-8-1", "fish-9-1", "fish-10-1" ]

  upload_blocks_to_gcloud         = false
  restart_nodes                   = false
  restart_nodes_every_mins        = "60"
  make_reports                    = true
  make_report_every_mins          = "5"
  make_report_discord_webhook_url = local.make_report_discord_webhook_url
  make_report_accounts            = local.make_report_accounts
  # seed_peers_url                  = "https://storage.googleapis.com/seed-lists/gossipqa_seeds.txt"
}
