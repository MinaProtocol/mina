output "confirmation" {
  value = "The new node VMs have been deployed sucessfully."
}

output "node_1_ip" {
  description = "The IP address of the first node:"
  value       = google_compute_address.node_1_address.address
}

output "ssh_instructions" {
  value = "gcloud compute ssh VM_NAME --zone=${var.gcp_zone}"
}
