variable "project_id" {
  description = "The project ID to deploy resources into"
}

variable "subnetwork_project" {
  description = "The project ID where the desired subnetwork is provisioned"
}

variable "subnetwork" {
  description = "The name of the subnetwork to deploy instances into"
}

variable "seed_peers" {
  type        = string
  default     = ""
  description = "An Optional space-separated list of -peer <peer-string> arguments for the mina daemon"
}

variable "instance_name" {
  description = "The desired name to assign to the deployed instance"
  default     = "coda-seed-node"
}

variable "zone" {
  description = "The GCP zone to deploy instances into"
  type        = string
}

variable "region" {
  description = "The GCP region to deploy addresses into"
  type        = string
}

variable "client_email" {
  description = "Service account email address"
  type        = string
  default     = ""
}

variable "cos_image_name" {
  description = "The forced COS image to use instead of latest"
  default     = "cos-stable-77-12371-89-0"
}

## Coda Vars

variable "discovery_keypair" {
  description = "The LibP2P Keypair to use when launching the seed node."
}

variable "mina_image" {
  description = "The docker image to deploy."
}

variable "runtime_config" {
  type = string
}
