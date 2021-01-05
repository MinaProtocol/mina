provider "google" {
  alias   = "google-us-east1"
  project = "o1labs-192920"
  region  = "us-east1"
  zone    = "us-east1-b"
}


module "testnet_east" {
  providers = {
    google = google.google-us-east1
  }
  source                = "../../modules/kubernetes/testnet"
  cluster_name          = "coda-infra-east"
  cluster_region        = "us-east1"
  testnet_name          = local.testnet_name
  coda_image            = local.coda_image
  coda_agent_image      = local.coda_agent_image
  coda_bots_image       = local.coda_bots_image
  coda_faucet_amount    = local.coda_faucet_amount
  coda_faucet_fee       = local.coda_faucet_fee

  seed_zone = "us-east1-b"
  seed_region = "us-east1"

  num_whale_block_producers = 5
  num_fish_block_producers = 200
  block_producer_key_pass = "naughty blue worm"
  block_producer_starting_host_port = 10001
  fish_block_producers_with_bots = [0]

  snark_worker_replicas = 128
  snark_worker_fee      = "0.025"
  snark_worker_public_key = "4vsRCVQZ41uqXfVVfkBNUuNNS7PgSJGdMDNAyKGDdU1WkdxxyxQ7oMdFcjDRf45fiGKkdYKkLPBrE1KnxmyBuvaTW97A5C8XjNSiJmvo9oHa4AwyVsZ3ACaspgQ3EyxQXk6uujaxzvQhbLDx"
  snark_worker_host_port = 10400

  agent_min_fee = "0.06"
  agent_max_fee = "0.06"
  agent_min_tx = "0.0015"
  agent_max_tx = "0.0015"
}

# Seed DNS
data "aws_route53_zone" "selected" {
  name = "o1test.net."
}

resource "aws_route53_record" "seed_one" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "seed-one.${local.testnet_name}.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = [module.testnet_east.seed_one_ip]
}

resource "aws_route53_record" "seed_two" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "seed-two.${local.testnet_name}.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = [module.testnet_east.seed_two_ip]
}

