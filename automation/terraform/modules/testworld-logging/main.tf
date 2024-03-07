terraform {
  backend "gcs" {
    bucket = "o1labs-terraform"
    prefix = "itn3-logging"
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

#####################################
# Google Cloud Secrets Imports
#####################################

data "google_secret_manager_secret_version" "itn_secret_key" {
  provider = google
  secret   = var.itn_secret_key
}

data "google_secret_manager_secret_version" "itn_db_pass" {
  provider = google
  secret   = var.db_pass
}

data "google_secret_manager_secret_version" "aws_access_id" {
  provider = google
  secret   = var.aws_id
}

data "google_secret_manager_secret_version" "aws_access_key" {
  provider = google
  secret   = var.aws_key
}

#####################################
# Docker Compose VM Configuration
#####################################

resource "random_id" "instance_id" {
  byte_length = 4
}

resource "google_compute_instance" "default" {
  name         = "itn-logging-${random_id.instance_id.hex}"
  machine_type = "n2-standard-32" # 32vCPU, 128GB RAM
  zone         = var.gcp_zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 500 # GB
    }
  }

  metadata = {
    startup-script = <<SCRIPT
  ${data.template_file.fe-config.rendered}
  ${data.template_file.keys.rendered}
  ${data.template_file.names-data.rendered}
  ${data.template_file.postgres.rendered}
  ${data.template_file.docker-script-build.rendered}
  ${data.template_file.docker-compose-build.rendered}
  ${data.template_file.execute-shell.rendered}
  SCRIPT
  }

  network_interface {
    network = "default"

    access_config {
      # do not remove
      # empty block required for ephemeral public IP
    }
  }

  labels = {
    service = var.billing_label
  }

  # depends_on = [google_sql_user.database_user]
}

#####################################
# Cloud Postgres Configuration
#####################################

# # Create a Google Cloud SQL PostgreSQL instance
# resource "google_sql_database_instance" "postgres_instance" {
#   name             = "my-postgres-instance"
#   database_version = "POSTGRES_14"
#   project          = var.gcp_project
#   region           = var.gcp_region
#   settings {
#     tier = "db-custom-1-3840"

#     # Set database flags
#     database_flags {
#       name  = "max_connections"
#       value = "10000"
#     }
#   }
#   deletion_protection = false
# }

# # Define the database user
# resource "google_sql_user" "database_user" {
#   name     = "my-db-user"
#   instance = google_sql_database_instance.postgres_instance.name
#   password = "your-password" # Change this to your desired password
# }
