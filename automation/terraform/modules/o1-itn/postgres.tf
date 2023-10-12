provider "google" {
  project = "o1labs-192920"
  region  = "us-east4"
  zone    = "us-east4-b"
}

data "google_secret_manager_secret_version" "db_username" {
  secret  = "projects/o1labs-192920/secrets/itn-db-user"
  version = "latest"
}

data "google_secret_manager_secret_version" "db_password" {
  secret  = "projects/o1labs-192920/secrets/itn-db-pass"
  version = "latest"
}

resource "google_sql_database_instance" "itn_instance" {
  name             = "itn-postgresql-instance"
  database_version = "POSTGRES_15"

  settings {
    user_labels = {
      "service" = var.resource_label
    }
    tier              = "db-custom-64-65536" # 64GB RAM, 64 Cores
    availability_type = "ZONAL"              # Turn off high availability
    backup_configuration {
      enabled = true
    }
  }

  deletion_protection = false # Disable deletion protection
  depends_on          = [google_project_service.sqladmin]


}

resource "google_project_service" "sqladmin" {
  project = "o1labs-192920"
  service = "sqladmin.googleapis.com"
}

resource "google_sql_database" "itn_database" {
  name      = var.db_name
  instance  = google_sql_database_instance.itn_instance.name
  charset   = "UTF8"
  collation = "en_US.UTF8"
}

resource "google_sql_user" "itn_user" {
  instance = google_sql_database_instance.itn_instance.name
  name     = data.google_secret_manager_secret_version.db_username.secret
  password = data.google_secret_manager_secret_version.db_password.secret
}
