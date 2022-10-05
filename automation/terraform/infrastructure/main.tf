terraform {
  required_version = ">= 0.12.0"
  backend "s3" {
    key     = "terraform-coda-infra.tfstate"
    encrypt = true
    region  = "us-west-2"
    bucket  = "o1labs-terraform-state"
    acl     = "bucket-owner-full-control"
  }
}

locals {
  gcp_project        = "o1labs-192920"
  num_nodes_per_zone = 1
  node_type          = "n1-standard-16"

  storage_reclaim_policies = [
    "Delete",
    "Retain"
  ]
}

data "google_client_config" "current" {}
