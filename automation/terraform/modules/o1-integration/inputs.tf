provider "google" {
  alias = "gke"
}

variable "deploy_graphql_ingress" {
  type = bool
}

variable "aws_route53_zone_id" {
  type = string
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
  default = "4vsRCVadXwWMSGA9q81reJRX3BZ5ZKRtgZU7PtGsNq11w2V9tUNf4urZAGncZLUiP4SfWqur7AZsyhJKD41Ke7rJJ8yDibL41ePBeATLUnwNtMTojPDeiBfvTfgHzbAVFktD65vzxMNCvvAJ"

}

variable "log_precomputed_blocks" {
  type = bool
}

variable "archive_configs" {
  description = "individual archive-node deployment configurations"
  default = null
}

variable "archive_node_count" {
  type = number
}

variable "mina_archive_schema" {
  type = string
}

variable "mina_archive_schema_aux_files" {
  type    = list(string)
  default = []
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
