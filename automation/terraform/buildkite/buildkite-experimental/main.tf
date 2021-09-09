terraform {
  required_version = ">= 0.13.3"
  backend "s3" {
    key     = "terraform-bk-experimental.tfstate"
    encrypt = true
    region  = "us-west-2"
    bucket  = "o1labs-terraform-state"
    acl     = "bucket-owner-full-control"
  }
}

provider "aws" {
  region = "us-west-2"
}

#
# OPTIONAL: input variables
#

variable "agent_vcs_privkey" {
  type = string

  description = "Version control private key for secured repository access"
  default     = ""
}

variable "google_credentials" {
  type = string

  description = "Custom operator Google Cloud Platform access credentials"
  default     = ""
}

