variable "gcp_project" {
  default = "o1labs-192920"
}

variable "gcp_region" {
  default = "us-east4"
}

variable "gcp_zone" {
  default = "us-east4-b"
}

data "template_file" "docker-script-build" {
  template = file("templates/docker-script-build.tpl")
}

data "template_file" "docker-compose-build" {
  template = file("templates/docker-compose-build.tpl")
}

data "template_file" "execute-shell" {
  template = file("templates/execute-shell.tpl")
}

data "template_file" "fe-config" {
  template = file("templates/docker-mounts/fe-config.tpl")
}

data "template_file" "keys" {
  template = file("templates/docker-mounts/keys.tpl")
}

data "template_file" "names-data" {
  template = file("templates/docker-mounts/names-data.tpl")
}

data "template_file" "postgres" {
  template = file("templates/docker-mounts/postgres.tpl")
}
