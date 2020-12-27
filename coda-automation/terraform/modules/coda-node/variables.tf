variable "instance_type" {
  description = "Type of instance to launch Coda on"
  type        = string
  default     = "c5.large"
}

variable "custom_ami" {
  description = "Optional Custom AMI - Defaults to newest debian stretch AMI"
  type = string
  default = ""
}

variable "netname" {
  description = "Name of the testnet, used for tagging resources"
  type        = string
  default     = "NONETNAMESET"
}

variable "coda_repo" {
  description = "repo of the Coda Deb to Install"
  type = string
  default = "stable"
}

variable "coda_version" {
  description = "Version of the Coda Deb to Install"
  type = string
  default = "0.0.1-release-beta-0d13213e"
}

variable "coda_variant" {
  description = "The variant (build profile) of the Coda Deb to install"
  type  = string
  default = "testnet-postake-medium-curves"
}

variable "port_rpc" {
  description = "Port RPC protocol communicates over"
  type        = number
  default     = 8301
}

variable "port_gossip" {
  description = "Port Gossip protocol communicates over"
  type        = number
  default     = 8302
}

variable "port_dht" {
  description = "Port DHT protocol communicates over"
  type        = number
  default     = 8303
}

variable "port_libp2p" {
  description = "Port libp2p protocol communicates over"
  type        = number
  default     = 8303
}

variable "port_ql" {
  description = "Port GraphQL endpoint is listening on"
  type        = number
  default     = 8304
}

variable "public_key" {
  description = "An SSH Public Key used to configure node access, if not set defaults to key_name"
  type        = "string"
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDKIzMn7890zeG1cdYEaxFhpTPY1ylgZKPZD/BKrVos7Yq6tTmqevQMXHSyvtbaQ7CQoyCiCAShFFzMjNelQ1q1X8Uo45YS4HL12eaqE9mbgwzVyaz5njL/N3DihxFqK5MGzolAh/Y/IerRzjq3f17twSzJwNOoiiqVoKk/JPeZUdvIKnrq09LckZ2ImWY520QchNS8bUHM1whlDU41Ovm/64cuheaLcI5+hz0Jc698YrQ83yh8Q0eo9qCmp7cE7JnLn5psxMwAVBSUHANret751qZZWvfNxwrV0J+UvHSVULtKyaM5WhM0dah9u+g84Lmoy+RRM5JfJGAa1VwtXibT testnet"
}

variable "key_name" {
  description = "The name of an AWS Public Key"
  type        = "string"
  default = ""
}

variable "region" {
  description = "The region the module should be deployed to"
  type        = string
  default     = "us-west-2"
}

#Options: "seed", "snarker",  "joiner", "proposer"
variable "rolename" {
  description = "The role the node should assume when it starts up, also used for resource tagging"
  type        = string
}

variable "server_count" {
  description = "Number of Coda nodes to launch"
  type        = number
  default     = 1
}

variable "use_eip" {
  description = "If true, apply EIP"
  default     = true
}

variable "prometheus_cidr_blocks" {
  description = "One or more CIDR Blocks in use by Prometheus"
  default = ["18.237.92.200/32", "52.35.51.5/32"]
}
