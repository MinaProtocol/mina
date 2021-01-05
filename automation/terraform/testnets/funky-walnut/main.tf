terraform {
  required_version = "~> 0.12.0"
  backend "s3" {
    key     = "terraform-funky-walnut.tfstate"
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
  testnet_name = "funky-walnut"
  coda_image   = var.coda_image
  coda_agent_image = var.coda_agent_image
  coda_bots_image = var.coda_bots_image
  coda_points_image = var.coda_points_image
  coda_faucet_amount = var.coda_faucet_amount
  coda_faucet_fee = var.coda_faucet_fee
}

variable "coda_image" {
  type = string
  default = "codaprotocol/coda-daemon:0.0.12-beta-feature-bump-genesis-timestamp-0e1c811"
}

variable "coda_agent_image" {
  type = string
  default = "codaprotocol/coda-user-agent:0.1.5"
}

variable "coda_bots_image" {
  type = string
  default = "codaprotocol/coda-bots:0.0.13-beta-1"
}

variable "coda_points_image" {
  type = string
  default = "codaprotocol/coda-points-hack:32b.1"
}

variable "coda_faucet_amount" {
  type    = string
  default = "10000000000"
}

variable "coda_faucet_fee" {
  type    = string
  default = "100000000"
}
