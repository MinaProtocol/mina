# Define the provider (Google Cloud)
provider "google" {
  project = "o1labs-192920"
  region  = "us-east4"
  zone    = "us-east4-b"
}

# Create a Google Cloud SQL PostgreSQL instance
resource "google_sql_database_instance" "postgres_instance" {
  name             = "my-postgres-instance"
  database_version = "POSTGRES_14"
  project          = "o1labs-192920"
  region           = "us-east4"
  settings {
    tier = "db-custom-1-3840"
  }
}

# Define the database user
resource "google_sql_user" "database_user" {
  name     = "my-db-user"
  instance = google_sql_database_instance.postgres_instance.name
  password = "your-password" # Change this to your desired password
}

# Output the connection name of the PostgreSQL instance
output "connection_name" {
  value = google_sql_database_instance.postgres_instance.connection_name
}
