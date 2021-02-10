output "seed_addresses" {
  value = local.seed_peers
}

output "external_seed_ip" {
  value = google_compute_address.seed_static_ip.address
}
