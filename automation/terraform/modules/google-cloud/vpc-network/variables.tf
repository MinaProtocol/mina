variable "project_id" {
  description = "The project ID to deploy resources into"
}

variable "network_name" {
  type    = string
  default = "coda-testnet"
}

variable "network_region" {
  type    = string
  default = "us-west1"
}

variable "subnet_name" {
  type    = string
  default = "coda-subnet"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

