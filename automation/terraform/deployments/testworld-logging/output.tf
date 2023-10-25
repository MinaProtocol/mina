output "docker_vm_ip" {
  value = google_compute_instance.default.network_interface.0.access_config.0.nat_ip
}

# output "cloud_postgres_ip" {
#   value = google_sql_database_instance.postgres_instance.ip_address
# }
