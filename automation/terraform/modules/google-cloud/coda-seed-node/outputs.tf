
output "instance_external_ip" {
  value = google_compute_address.external_ip.address
}

output "discovery_keypair" {
  value = var.discovery_keypair
}