terraform {
  backend "gcs" {
    bucket = "o1labs-terraform"
    prefix = "itn3-vm-nodes"
  }
}

provider "google" {
  project = var.gcp_project
  region  = var.gcp_region
  zone    = var.gcp_zone
}

#####################################
# Google Cloud Secrets Imports
#####################################

data "google_secret_manager_secret_version" "itn_log_backend_keys" {
  provider = google
  secret   = var.itn_log_backend_keys
}

data "google_secret_manager_secret_version" "itn_node_vm_1_libp2p_pass" {
  provider = google
  secret   = var.itn_node_vm_1_libp2p_pass
}

data "google_secret_manager_secret_version" "itn_node_vm_1_privkey" {
  provider = google
  secret   = var.itn_node_vm_1_privkey
}

data "google_secret_manager_secret_version" "itn_node_vm_1_privkey_pass" {
  provider = google
  secret   = var.itn_node_vm_1_privkey_pass
}

data "google_secret_manager_secret_version" "itn_node_vm_1_pubkey" {
  provider = google
  secret   = var.itn_node_vm_1_pubkey
}

#####################################
# Deploying Resources
#####################################

resource "google_compute_address" "node_1_address" {
  name = "itn3-node-1-static-ip"
}

resource "google_compute_instance_template" "itn3_node_1" {
  name_prefix  = "whale-template-"
  machine_type = "n2-standard-8"

  network_interface {
    network = "default"

    access_config {
      nat_ip = google_compute_address.node_1_address.address
    }
  }

  disk {
    boot         = true
    disk_type    = "pd-standard"
    source_image = "debian-cloud/debian-10"
  }

  metadata = {
    startup-script = <<SCRIPT
  ${data.template_file.mina-config-node-1.rendered}
  ${data.template_file.startup.rendered}
  SCRIPT
  }

  lifecycle {
    create_before_destroy = false
  }

  labels = {
    service = var.billing_label
  }

  tags = var.firewall_label
}

resource "google_compute_instance_group_manager" "node-1" {
  name               = "node-1-mig"
  base_instance_name = "itn3-node-1"
  version {
    instance_template = google_compute_instance_template.itn3_node_1.id
  }

  target_size = 1

  named_port {
    name = "http"
    port = 3086
  }
}

resource "google_compute_firewall" "allow_http_3086" {
  name    = "allow-http-3086"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["3086"]
  }

  source_ranges = ["0.0.0.0/0"]

  target_tags = var.firewall_label
}
