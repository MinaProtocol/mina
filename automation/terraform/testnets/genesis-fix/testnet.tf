terraform {
  required_version = "~> 0.12.0"
  backend "s3" {
    key     = "terraform-genesis-fix.tfstate"
    encrypt = true
    region  = "us-west-2"
    bucket  = "o1labs-terraform-state"
    acl     = "bucket-owner-full-control"
  }
}

provider "aws" {
  region = "us-west-2"
}

locals {
  netname    = "genesis-test"
  coda_image = "codaprotocol/coda-daemon:0.0.11-beta5-release-0.0.11-beta5-redux-9116312"
}

provider "google" {
  project = "o1labs-192920"
  region  = "us-west1"
  zone    = "us-west1-a"
}

# Defaults to the provider project
data "google_project" "project" {
}

module "network" {
  source         = "../../modules/google-cloud/vpc-network"
  network_name   = "${local.netname}-testnet-network"
  network_region = "us-west1"
  subnet_name    = "${local.netname}-testnet-subnet"
}

module "seed_one" {
  source             = "../../modules/google-cloud/coda-seed-node"
  coda_image         = local.coda_image
  project_id         = data.google_project.project.project_id
  subnetwork_project = data.google_project.project.project_id
  subnetwork         = module.network.subnet_link
  network            = module.network.network_link
  instance_name      = "${local.netname}-seed-one"
  zone               = "us-west1-a"
  region             = "us-west1"
  client_email       = "1020762690228-compute@developer.gserviceaccount.com"
  discovery_keypair  = "23jhTeLbLKJSM9f3xgbG1M6QRHJksFtjP9VUNUmQ9fq3urSovGVS25k8LLn8mgdyKcYDSteRcdZiNvXXXAvCUnST6oufs,4XTTMESM7AkSo5yfxJFBpLr65wdVt8dfuQTuhgQgtnADryQwP,12D3KooWP7fTKbyiUcYJGajQDpCFo2rDexgTHFJTxCH8jvcL1eAH"
  seed_peers         = ""
}

module "seed_two" {
  source             = "../../modules/google-cloud/coda-seed-node"
  coda_image         = local.coda_image
  project_id         = data.google_project.project.project_id
  subnetwork_project = data.google_project.project.project_id
  subnetwork         = module.network.subnet_link
  network            = module.network.network_link
  instance_name      = "${local.netname}-seed-two"
  zone               = "us-west1-a"
  region             = "us-west1"
  client_email       = "1020762690228-compute@developer.gserviceaccount.com"
  discovery_keypair  = "23jhTbijdCA9zioRbv7HboRs7F8qZL59N5GQvGzhfB3MrS5qNrQK5fEdWyB5wno9srsDFNRc4FaNUDCEnzJGHG9XX6iSe,4XTTMBUfbSrzTGiKVp8mhZCuE9nDwj3USx3WL2YmFpP4zM2DG,12D3KooWL9ywbiXNfMBqnUKHSB1Q1BaHFNUzppu6JLMVn9TTPFSA"
  seed_peers         = "-peer /ip4/${module.seed_one.instance_external_ip}/tcp/10002/p2p/12D3KooWP7fTKbyiUcYJGajQDpCFo2rDexgTHFJTxCH8jvcL1eAH"
}

# Seed DNS
data "aws_route53_zone" "selected" {
  name = "o1test.net."
}

resource "aws_route53_record" "seed_one" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "seed-one.${local.netname}.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = [module.seed_one.instance_external_ip]
}

resource "aws_route53_record" "seed_two" {
  zone_id = "${data.aws_route53_zone.selected.zone_id}"
  name    = "seed-two.${local.netname}.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "300"
  records = [module.seed_two.instance_external_ip]
}
