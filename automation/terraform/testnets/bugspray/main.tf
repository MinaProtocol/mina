terraform {
  required_version = ">= 0.12.0"
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

locals {
  testnet_name = "bugspray"
  mina_image   = var.mina_image
  mina_agent_image = var.mina_agent_image
  mina_bots_image = var.mina_bots_image
  coda_faucet_amount = var.coda_faucet_amount
  coda_faucet_fee = var.coda_faucet_fee
}

variable "mina_image" {
  type = string
  default = "codaprotocol/coda-daemon:0.0.12-beta-feature-bump-genesis-timestamp-16200a0"
}

variable "mina_agent_image" {
  type = string
  default = "codaprotocol/coda-user-agent:0.1.5"
}

variable "mina_bots_image" {
  type = string
  default = "codaprotocol/coda-bots:0.0.13-beta-1"
}

variable "coda_faucet_amount" {
  type    = string
  default = "10000000000"
}

variable "coda_faucet_fee" {
  type    = string
  default = "100000000"
}
