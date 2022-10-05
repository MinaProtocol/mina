output "network_link" {
  value = google_compute_network.default.self_link
}

output "network_region" {
  value = google_compute_subnetwork.default.region
}

output "subnet_link" {
  value = google_compute_subnetwork.default.self_link
}
