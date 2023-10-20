variable "gcp_project" {
  default = "o1labs-192920"
}

variable "gcp_region" {
  default = "us-east4"
}

variable "gcp_zone" {
  default = "us-east4-b"
}

variable "db_name" {
  default = "o1db"
}

variable "db_user" {
  default = "postgres"
}

variable "db_pass" {
  default = "o1db-pass"
}

variable "deletion_protection" {
  default = false
}

variable "postgres_version" {
  default = "POSTGRES_14"
}

variable "db_spec" {
  default = "db-g1-small"
}
