variable "name" {
  description = "Name for the ECS Cluster"
  type = string
}

variable "environment" {
  description = "Environment this cluster is operating under"
  type = string
  default = "dev"
}

variable "cluster_desired_capacity" {
  description = "Desired number of ECS Nodes"
  type = string
  default = "2"
}

variable "cluster_max_size" {
  description = "Maximum Size of the ECS Cluster"
  type = string
  default = "3"
}

variable "cluster_instance_type" {
  description = "The type of instance to launch ECS Nodes with"
  type = string
  default = "t3.xlarge"
}

variable "cluster_ssh_key_name" {
  description = "The name of an SSH key to install on ECS Nodes"
  default = "testnet"
}
