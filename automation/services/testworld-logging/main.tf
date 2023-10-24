# Configure the Google Cloud provider
provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

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


// Terraform plugin for creating random ids
// https://cloud.google.com/community/tutorials/getting-started-on-gcp-with-terraform
resource "random_id" "instance_id" {
  byte_length = 4
}

// A single Google Cloud Engine instance
resource "google_compute_instance" "default" {
  name         = "itn-logging-${random_id.instance_id.hex}"
  machine_type = "n1-standard-16"
  zone         = var.gcp_zone

  # tags = ["http-server","https-server"] #uncomment to allow 80 and or 443

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-10"
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
      // Include this section to give the VM an external ip address

    }
  }
  // depends_on = [google_sql_user.database_user]
}
