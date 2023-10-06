terraform {
  required_version = ">= 0.14.0"
  backend "s3" {
    key     = "terraform-testworld-v2.tfstate"
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
  type        = number
  description = "Number of online whales for the network to run"
  default     = 2
}

variable "fish_count" {
  type        = number
  description = "Number of online fish for the network to run"
  default     = 0
}

variable "seed_count" {
  default = 3
}

variable "plain_node_count" {
  default = 0
}

locals {
  testnet_name                    = "testworld-2-0"
  mina_image                      = "gcr.io/o1labs-192920/mina-daemon:2.0.0rampup2-berkeley-itn3-ledger-validate-25f9de2-focal-berkeley"
  mina_archive_image              = "gcr.io/o1labs-192920/mina-archive:2.0.0rampup2-berkeley-itn3-ledger-validate-25f9de2-focal"
  seed_region                     = "us-central1"
  seed_zone                       = "us-central1-b"
  make_report_discord_webhook_url = ""
  make_report_accounts            = ""
}

module "testworld-2-0" {
  providers = { google.gke = google.google-us-central1 }
  source    = "../../modules/o1-testnet"

  artifact_path = abspath(path.module)

  cluster_name   = "coda-infra-central1"
  cluster_region = "us-central1"
  k8s_context    = "gke_o1labs-192920_us-central1_coda-infra-central1"
  testnet_name   = local.testnet_name

  mina_image                  = local.mina_image
  mina_archive_image          = local.mina_archive_image
  mina_agent_image            = "codaprotocol/coda-user-agent:0.1.8"
  mina_bots_image             = "codaprotocol/coda-bots:0.0.13-beta-1"
  mina_points_image           = "codaprotocol/coda-points-hack:32b.4"
  watchdog_image              = "gcr.io/o1labs-192920/watchdog:0.4.13"
  use_embedded_runtime_config = true

  archive_node_count            = 3
  mina_archive_schema           = "create_schema.sql"
  mina_archive_schema_aux_files = ["https://raw.githubusercontent.com/MinaProtocol/mina/20a2b3ab80546d06a69996e6ad76e112b727b79b/src/app/archive/create_schema.sql", "https://raw.githubusercontent.com/MinaProtocol/mina/20a2b3ab80546d06a69996e6ad76e112b727b79b/src/app/archive/zkapp_tables.sql"]

  archive_configs = [
    {
      name              = "archive-1"
      enableLocalDaemon = true
      enablePostgresDB  = true
      postgresHost      = "archive-1-postgresql"
    },
    {
      name              = "archive-2"
      enableLocalDaemon = true
      enablePostgresDB  = true
      postgresHost      = "archive-2-postgresql"
    }
  ]

  mina_faucet_amount = "10000000000"
  mina_faucet_fee    = "100000000"

  agent_min_fee         = "0.05"
  agent_max_fee         = "0.1"
  agent_min_tx          = "0.0015"
  agent_max_tx          = "0.0015"
  agent_send_every_mins = "1"

  seed_zone   = local.seed_zone
  seed_region = local.seed_region

  log_level           = "Debug"
  log_txn_pool_gossip = false

  block_producer_key_pass           = ""
  block_producer_starting_host_port = 10501

  worker_cpu_request = 4
  cpu_request        = 8
  worker_mem_request = "6Gi"
  mem_request        = "12Gi"

  snark_coordinators = [
    {
      snark_worker_replicas        = 5
      snark_worker_fee             = "0.01"
      snark_worker_public_key      = "B62qmQsEHcsPUs5xdtHKjEmWqqhUPRSF2GNmdguqnNvpEZpKftPC69e"
      snark_coordinators_host_port = 10401
    }
  ]

  seed_count       = var.seed_count
  plain_node_count = 0

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

  upload_blocks_to_gcloud         = true
  restart_nodes                   = false
  restart_nodes_every_mins        = "60"
  make_reports                    = true
  make_report_every_mins          = "5"
  make_report_discord_webhook_url = local.make_report_discord_webhook_url
  make_report_accounts            = local.make_report_accounts
  seed_peers_url                  = "https://storage.googleapis.com/seed-lists/testworld-2-0_seeds.txt"
}

resource "helm_release" "itn-services" {
  provider  = helm.testnet_deploy
  name      = "itn-services"
  chart     = "../../../../helm/itn-services"
  namespace = kubernetes_namespace.testnet_namespace.metadata[0].name

  #   set {
  #     name  = "replicaCount"
  #     value = 3
  #   }

  depends_on = [module.testworld-2-0] # requires the ITN testnet to deploy first
}



# resource "helm_release" "seeds" {
#   provider = helm.testnet_deploy

#   name       = "${var.testnet_name}-seeds"
#   repository = var.use_local_charts ? "" : local.mina_helm_repo
#   chart      = var.use_local_charts ? "../../../../helm/seed-node" : "seed-node"
#   version    = "1.0.11"
#   namespace  = kubernetes_namespace.testnet_namespace.metadata[0].name
#   values = [
#     yamlencode(local.seed_vars)
#   ]
#   wait    = false
#   timeout = 600
#   depends_on = [
#     kubernetes_role_binding.helm_release
#   ]
# }

