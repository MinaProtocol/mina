variable "create_iam_service_linked_role" {
  description = "Whether to create IAM service linked role for AWS ElasticSearch service. Can be only one per AWS account."
  default     = true
}

variable "domain_name" {
  description = "Domain name for Elasticsearch cluster"
  default     = "es-domain"
}

variable "es_version" {
  description = "Version of Elasticsearch to deploy (default 5.1)"
  default     = "6.7"
}

variable "instance_type" {
  description = "ES instance type for data nodes in the cluster (default t2.small.elasticsearch)"
  default     = "t2.small.elasticsearch"
}

variable "instance_count" {
  description = "Number of data nodes in the cluster (default 6)"
  default     = 6
}

variable "dedicated_master_type" {
  description = "ES instance type to be used for dedicated masters (default same as instance_type)"
  default     = false
}

variable "encrypt_at_rest" {
  description = "Enable encrption at rest (only specific instance family types support it: m4, c4, r4, i2, i3 default: false)"
  default     = false
}

variable "management_iam_roles" {
  description = "List of IAM role ARNs from which to permit management traffic (default ['*']).  Note that a client must match both the IP address and the IAM role patterns in order to be permitted access."
  type        = "list"
  default     = ["*"]
}

variable "management_public_ip_addresses" {
  description = "List of IP addresses from which to permit management traffic (default []).  Note that a client must match both the IP address and the IAM role patterns in order to be permitted access."
  type        = "list"
  default     = []
}

variable "es_zone_awareness" {
  description = "Enable zone awareness for Elasticsearch cluster (default false)"
  default     = "false"
}

variable "ebs_volume_size" {
  description = "Optionally use EBS volumes for data storage by specifying volume size in GB (default 0)"
  default     = 0
}

variable "ebs_volume_type" {
  description = "Storage type of EBS volumes, if used (default gp2)"
  default     = "gp2"
}

variable "kms_key_id" {
  description = "KMS key used for elasticsearch"
  default     = ""
}

variable "snapshot_start_hour" {
  description = "Hour at which automated snapshots are taken, in UTC (default 0)"
  default     = 0
}

variable "tags" {
  description = "tags to apply to all resources"
  type        = "map"
  default     = {}
}

variable "use_prefix" {
  description = "Flag indicating whether or not to use the domain_prefix. Default: true"
  default     = true
}

variable "domain_prefix" {
  description = "String to be prefixed to search domain. Default: tf-"
  default     = "tf-"
}

variable "dedicated_master_threshold" {
  description = "The number of instances above which dedicated master nodes will be used. Default: 10"
  default     = 10
}

variable "advanced_options" {
  description = "Map of key-value string pairs to specify advanced configuration options. Note that the values for these configuration options must be strings (wrapped in quotes) or they may be wrong and cause a perpetual diff, causing Terraform to want to recreate your Elasticsearch domain on every apply."
  default     = {}
}

# variable "log_publishing_options" {
#   description = "Map of options for publishing slow logs to CloudWatch Logs."
#   default     = {}
# }

variable "node_to_node_encryption_enabled" {
  description = "Whether to enable node-to-node encryption."
  default     = false
}