# Global Vars

variable "environment" {
  description = "The environment the service is running in"
  type        = string
  default     = "dev"
}

variable "testnet" {
  description = "The testnet that this daemon is connected to"
  type        = string
}

variable "ecs_cluster_id" {
  description = "The ECS Cluster this service should be deployed to"
  type        = string
}

# FAUCET VARIABLES
variable "faucet_container_version" {
  description = "The version of the container to be used when deploying the Faucet Service"
  type        = string
}

variable "discord_api_key" {
  description = "A Discord Bot API Key"
  type        = string
}

variable "coda_graphql_host" {
  description = "The hostname of the Coda GraphQL Endpoint"
  type        = string
  default     = "localhost"
}

variable "coda_graphql_port" {
  description = "The port the Coda GraphQL Endpoint is listening on"
  type        = string
  default     = "3085"
}

variable "faucet_public_key" {
  description = "The Public Key to be used by the Faucet Service, must be installed as a wallet on the Coda Daemon"
  type        = string
}

variable "faucet_password" {
  description = "The password for the private key in use by the Faucet Service"
  type        = string
}

variable "echo_public_key" {
  description = "The Public Key to be used by the Echo Service, must be installed as a wallet on the Coda Daemon"
  type        = string
}

variable "echo_password" {
  description = "The password for the private key in use by the Echo Service"
  type        = string
}

variable "fee_amount" {
  description = "The default fee to be used by the Faucet and Echo Services"
  type        = string
}

# DAEMON VARIABLES

variable "coda_container_version" {
  description = "The version of the container to be used when deploying the Faucet Service"
  type        = string
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

variable "coda_peer" {
  description = "The initial peer to start the Daemon with"
  type        = string
}

variable "coda_rest_port" {
  description = "The port that the GraphQL server will listen on"
  type        = string
  default     = "3085"
}

variable "coda_external_port" {
  description = "The port that the daemon will listen for RPC connections"
  type        = string
  default       = "10101"
}

variable "coda_discovery_port" {
  description = "The port that the daemon will listen for RPC connections"
  type        = string
  default       = "10102"
}

variable "coda_metrics_port" {
  description = "The port that the daemon will expose prometheus metrics on"
  type        = string
  default       = "10000"
}

variable "coda_client_port" {
  description = "The port that the daemon will expose prometheus metrics on"
  type        = string
  default       = "10103"
}

variable "coda_privkey_pass" {
  description = "The password for the installed keys"
  type        = string
}