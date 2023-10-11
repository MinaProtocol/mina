# provider "google" {
#   project = "o1labs-192920"
#   region  = "us-east4"
#   zone    = "us-east4-b"
# }

resource "google_sql_database_instance" "itn_instance" {
  name             = "itn-postgresql-instance"
  database_version = "POSTGRES_13"

  settings {
    tier = "db-custom-2-4096" # Set desired machine type (e.g., custom, db-n1-standard-1, etc.)
  }

  deletion_protection = false # Disable deletion protection
  depends_on          = [google_project_service.sqladmin]
}

resource "google_project_service" "sqladmin" {
  project = "o1labs-192920"
  service = "sqladmin.googleapis.com"
}

resource "google_sql_database" "itn_database" {
  name      = "itn-database"
  instance  = google_sql_database_instance.itn_instance.name
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

resource "google_sql_user" "itn_user" {
  name     = "itn-db-user" # Set the username for your database
  instance = google_sql_database_instance.itn_instance.name
  password = "" # Set the desired password
}

