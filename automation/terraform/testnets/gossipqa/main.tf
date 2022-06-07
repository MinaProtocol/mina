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
  default     = 6
}

variable "plain_node_count" {
  default     = 1
}

locals {
  testnet_name = "gossipqa"
  mina_image = "minaprotocol/mina-daemon:1.3.1beta1-metrics-gossip-data-collection-92db0c6-focal-devnet"
  mina_archive_image = "minaprotocol/mina-archive:1.3.1beta1-metrics-gossip-data-collection-92db0c6-focal"
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
      snark_worker_public_key = "B62qrtM9sqxvu3Y7s2KXBSzxZHs9SURN7xSRoBNRemUNaN494mybRVc"
      snark_coordinators_host_port = 10401
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qr6jbkibG3BdvUGEYZaMR2yrtQxwkumyLKd9QgGhJ6oLJ5A5sd4g"
      snark_coordinators_host_port = 10402
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qm2XoqdhFQeyy5hrvyg5D9UnRXQw4xY9CYa5rqnNSZwFyVaENE7J"
      snark_coordinators_host_port = 10403
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qoREavDYSGa5L1UVZW42m29hcPYwEwmWdBJ1GUzsihVVFHkqF2x6"
      snark_coordinators_host_port = 10404
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qmgEgYZYf6uwFifNyfigx4WRiGznchgStn7c5SKKe4vPQQZupuLz"
      snark_coordinators_host_port = 10405
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qptG6paTZSV35CAtfhyEv6xSnxC9wagLkDUeg5oeyHcDqRFgeztH"
      snark_coordinators_host_port = 10406
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qmkdnR9LVbUFJygPBRJERZ2LbHNpktmpWUJRv5HyPXMu17LbGxSW"
      snark_coordinators_host_port = 10407
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qpC52Xa9CJswwWnUbNrV56ia1a7TNfwcqMRkS4dL4Ca94rFUCEVU"
      snark_coordinators_host_port = 10408
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qkK6SYevpNwmCBMkKg9teBkBY398Ji5szhLbg9uesEXhu9x6dgcX"
      snark_coordinators_host_port = 10409
    },
        {
      snark_worker_replicas = 5
      snark_worker_fee      = "0.025"
      snark_worker_public_key = "B62qrZXxFq7fr66mG5xNmUGgk8fAPrxqStNvRHWADsE4UQeTGbqNaKs"
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
