terraform {
  required_version = ">= 0.14.0"
  backend "s3" {
    key     = "ci-net.tfstate"
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
  zone    = "us-west1a"
}

module "ci_testnet" {
  providers = { google.gke = google.google-us-west1 }
  source    = "../../modules/o1-integration"
  k8s_context = "gke_o1labs-192920_us-west1_mina-integration-west1"
  cluster_name = "mina-integration-west1"
  cluster_region = "us-west1"
  aws_route53_zone_id = "ZJPR9NA6W9M7F"
  testnet_name = "it-darek-53ccec09-chain-reliability"
  deploy_graphql_ingress = true
  mina_image ="gcr.io/o1labs-192920/mina-daemon:2.0.0rampup2-berkeley-53ccec0-bullseye-berkeley"
  mina_agent_image = "codaprotocol/coda-user-agent:0.1.5"
  mina_bots_image = "minaprotocol/mina-bots:latest"
  mina_points_image = "codaprotocol/coda-points-hack:32b.4"
  mina_archive_image =  "gcr.io/o1labs-192920/mina-archive:2.0.0rampup2-berkeley-53ccec0-bullseye"
  log_precomputed_blocks = false
  archive_node_count = 0
  mina_archive_schema = "create_schema.sql"
  cpu_request = 6
  mem_request ="12Gi"
  worker_cpu_request = 6
  worker_mem_request = "8Gi"
  pod_priority = 992507537
  snark_worker_fee= "0.025"
  runtime_config ="{\"daemon\":{\"txpool_max_size\":3000},\"genesis\":{\"k\":20,\"delta\":0,\"slots_per_epoch\":480,\"slots_per_sub_window\":2,\"genesis_state_timestamp\":\"2023-10-23 11:53:05.963009Z\"},\"proof\":{\"level\":\"full\",\"block_window_duration_ms\":120000},\"ledger\":{\"accounts\":[{\"pk\":\"B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX\",\"sk\":\"EKDxCqQGa39sTxtecX4gRmw8MzpG3JB8ooL8uDNqE75sj2uegkuz\",\"balance\":\"1000\"},{\"pk\":\"B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93\",\"sk\":\"EKEhAjWjbtAyppEPYUMYaEBuLv2gfgbAMvX2uTbtS2AyMpEmMtGU\",\"balance\":\"1000\"},{\"pk\":\"B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF\",\"sk\":\"EKDsKYn9FHx541TcemCx1Y1r2E6K9fZpbXPrfkW6m3X9nrS18RHk\",\"balance\":\"0\"}]}}"
      
  block_producer_configs = [
          {
            name = "node-a",
            keypair = {
              keypair= "B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX"
              keypair_name= "node-a-key"
              privkey_password = "naughty blue worm"
              public_key= "B62qrA2eWb592uRLtH5ohzQnx7WTLYp2jGirCw5M7Fb9gTf1RrvTPqX"
              private_key="{\"box_primitive\":\"xsalsa20poly1305\",\"pw_primitive\":\"argon2i\",\"nonce\":\"72AYESxUF218GvFwbrhh9ALDtd4uxTGnYMecdW4\",\"pwsalt\":\"89jtb4sadC7ncKX3i6JsWLXLpGfF\",\"pwdiff\":[134217728,6],\"ciphertext\":\"CYN6TDjWQDa4ocPUEHoHcHeBKihK9Ct8CxKu8yNwX32dvRMqPheg3MP219s3HAsTAfAZywPct\"}"
            }
            libp2p_secret = ""
          },
          {
            name = "node-b",
            keypair = {
              keypair ="B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93"
              keypair_name= "node-b-key"
              privkey_password= "naughty blue worm"
              public_key=        "B62qpkCEM5N5ddVsYNbFtwWV4bsT9AwuUJXoehFhHUbYYvZ6j3fXt93"
              private_key = "{\"box_primitive\":\"xsalsa20poly1305\",\"pw_primitive\":\"argon2i\",\"nonce\":\"7YYYCVkwYfSBznFwsHVmhDWMvUat3jjgJ8NZ76k\",\"pwsalt\":\"9iF3WEpK81Lhj1fEgbS19ZNixm1g\",\"pwdiff\":[134217728,6],\"ciphertext\":\"C39bNAjd4W4PkPLiMADMMS4RvkpGQfXdZnW7PFKjBhpu3f4qYLM2EQLC59aVU78kYce5aVwhE\"}"
            },
            "libp2p_secret": ""
          },
          {
            name=  "node-c"
            keypair = {
              keypair =        "B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF"
              keypair_name = "node-c-key"
              privkey_password = "naughty blue worm"
              public_key = "B62qp5sdhH48MurWgtHNkXUTphEmUfcKVmZFspYAqxcKZ7YxaPF1pyF"
              private_key = "{\"box_primitive\":\"xsalsa20poly1305\",\"pw_primitive\":\"argon2i\",\"nonce\":\"8cTaVRKDUF286tEYeVMWQWZMi1fegXmmTuj8Ped\",\"pwsalt\":\"BGbtYBKFk6mCoTzofnuVSNRmHoi3\",\"pwdiff\":[134217728,6],\"ciphertext\":\"Bp4bhwv7A9KxterbPH2wW6zZMkrzTeGRdVyj57GmWf6FEkU2BZh4gLAxWurqm7R5iHSTzVWtB\"}"
            },
            libp2p_secret= ""
          }
  ]
}


     
       
         