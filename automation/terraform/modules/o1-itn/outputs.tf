output "instance_name" {
  value = google_sql_database_instance.itn_instance.name
}

output "external_ip" {
  value = google_sql_database_instance.itn_instance.ip_address[0]
}
