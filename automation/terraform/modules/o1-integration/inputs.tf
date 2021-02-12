provider "google" {
  alias = "gke"
}

variable "cluster_name" {
  type = string
}

variable "cluster_region" {
  type = string
}

variable "k8s_context" {
  type = string
}

variable "testnet_name" {
  type = string
}

variable "mina_image" {
  type = string
}

variable "mina_archive_image" {
  type = string
}

variable "mina_agent_image" {
  type = string
}

variable "mina_bots_image" {
  type = string
}

variable "mina_points_image" {
  type = string
}

variable "runtime_config" {
  type = string
}

variable "snark_worker_replicas" {
  type = number
}

variable "snark_worker_fee" {
  type = string
}

variable "snark_worker_public_key" {
  type = string
}

variable "block_producer_configs" {
  type = list(
    object({
      name = string,
      id = string,
      public_key = string,
      private_key = string,
      keypair_secret = string,
      libp2p_secret = string
    })
  )
}
