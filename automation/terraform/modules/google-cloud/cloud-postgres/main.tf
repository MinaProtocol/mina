# Configure the Google Cloud provider
provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
}

resource "random_id" "instance_id" {
  byte_length = 4
}

data "google_secret_manager_secret_version" "db_password" {
  provider = google
  secret   = var.db_pass
}

# Create a Google Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "postgres_instance" {
  name             = "${var.db_name}-${random_id.instance_id.hex}"
  database_version = var.postgres_version
  project          = var.gcp_project
  region           = var.gcp_region
  settings {
    tier = var.db_spec
  }
  deletion_protection = var.deletion_protection
}

# Define the database user
resource "google_sql_user" "database_user" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres_instance.name
  password = data.google_secret_manager_secret_version.db_password.secret_data
}
