output "cloud_postgres_ip" {
  value = google_sql_database_instance.postgres_instance.ip_address
}

output "db_user" {
  value = google_sql_user.database_user.name
}

output "db_password" {
  value = data.google_secret_manager_secret_version.db_password.secret_data
}


