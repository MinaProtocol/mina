variable "cluster_id" {
  description = "The ECS cluster ID"
  type        = string
}

variable "environment" {
  description = "The ECS cluster ID"
  type        = string
  default = "dev"
}

variable "remote_write_uri" {
  description = "Remote Write URI for forwarded metrics"
}

variable "remote_write_username" {
  description = "Remote Write Username for forwarded metrics"
}


variable "remote_write_password" {
  description = "Remote Write Password for forwarded metrics"
}

variable "aws_access_key" {
  description = "Access Key for AWS - Read-only to EC2"
}

variable "aws_secret_key" {
  description = "Secret Key for AWS - Read-only to EC2"
}