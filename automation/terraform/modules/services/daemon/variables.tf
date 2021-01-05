variable "ecs_cluster_id" {
  description = "The ECS cluster ID"
  type        = string
}

variable "environment" {
  description = "The environment the service is running in"
  type        = string
  default = "dev"
}

variable "testnet" {
  description = "The testnet that this daemon is connected to"
  type        = string
}

variable "daemon_name" {
  description = "A unique value that is not shared with another deployed daemon"
  type        = string
  default = "dev-daemon"
}

variable "coda_container_version" {
  description = "The version of the container to be used when deploying the Daemon Service"
  type        = string
  default = "0.0.8-fix"
}

variable "coda_wallet_keys" {
  description = "A space-delimited list of AWS Secrets Manager secret IDs"
  type        = string
}

variable "aws_access_key" {
  description = "An Access Key granting read-only access to Testnet Secrets"
  type        = string
}

variable "aws_secret_key" {
  description = "The corresponding AWS Secret Key"
  type        = string
}

variable "aws_default_region" {
  description = "The region that the secrets are stored in"
  type        = string
}

variable "coda_snark_key" {
  description = "A Public Key to use for SNARK Work, does not need to be installed on the daemon"
  default = ""
}

variable "coda_propose_key" {
  description = "A Public Key to use for Block Producing, corresponding private key must be installed on the daemon"
  default = ""
}

variable "coda_peer" {
  description = "The initial peer to start the Daemon with"
  type        = string
}

variable "coda_rest_port" {
  description = "The port that the GraphQL server will listen on"
  type        = string
  default = "3085"
}

variable "coda_external_port" {
  description = "The port that the daemon will listen for RPC connections"
  type        = string
  default = "10101"
}

variable "coda_discovery_port" {
  description = "The port that the daemon will listen for RPC connections"
  type        = string
  default = "10102"
}

variable "coda_metrics_port" {
  description = "The port that the daemon will expose prometheus metrics on"
  type        = string
  default = "10103"
}

variable "coda_privkey_pass" {
  description = "The password for the installed keys"
  type        = string
}