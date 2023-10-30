variable "gcp_project" {
  default = "o1labs-192920"
}

variable "gcp_region" {
  default = "us-east4"
}

variable "gcp_zone" {
  default = "us-east4-b"
}

variable "billing_label" {
  default = "itn3"
}

#####################################
# Secret Vars
#####################################

variable "itn_secret_key" {
  default = "itn_secret_key" # name of secret in Google Cloud
}

variable "db_pass" {
  default = "itn-db-pass"
}

variable "aws_id" {
  default = "itn-aws-id"
}

variable "aws_key" {
  default = "itn-aws-key"
}

#####################################
# Passing Secrets To Templates
#####################################


data "template_file" "docker-script-build" {
  template = file("templates/docker-script-build.tpl")
}

data "template_file" "docker-compose-build" {
  template = file("templates/docker-compose-build.tpl")
  vars = {
    password_value = data.google_secret_manager_secret_version.itn_db_pass.secret_data
    aws_id_value   = data.google_secret_manager_secret_version.aws_access_id.secret_data
    aws_key_value  = data.google_secret_manager_secret_version.aws_access_key.secret_data
  }
}

data "template_file" "execute-shell" {
  template = file("templates/execute-shell.tpl")
}

data "template_file" "fe-config" {
  template = file("templates/docker-mounts/fe-config.tpl")
}

data "template_file" "keys" {
  template = file("templates/docker-mounts/keys.tpl")
  vars = {
    key_value = data.google_secret_manager_secret_version.itn_secret_key.secret_data
  }
}

data "template_file" "names-data" {
  template = file("templates/docker-mounts/names-data.tpl")
}

data "template_file" "postgres" {
  template = file("templates/docker-mounts/postgres.tpl")
}
