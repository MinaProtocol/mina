locals {
  container_command = format("mina daemon -log-level Info -config-directory /root/.mina-config -client-port 8301 -rest-port 8304 -external-port 10001 -metrics-port 10000 -libp2p-keypair %s -seed %s -config-file /root/daemon.json | tee log.txt", var.discovery_keypair, var.seed_peers)
}

resource "google_compute_address" "external_ip" {
  name         = "${var.instance_name}-address"
  address_type = "EXTERNAL"
  region       = var.region
  project      = var.project_id
}

resource "google_compute_instance" "vm" {
  project      = var.project_id
  name         = var.instance_name
  machine_type = "n1-standard-4"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = data.google_compute_image.coreos.self_link
      size = 20
    }
  }

  network_interface {
    subnetwork_project = var.subnetwork_project
    subnetwork         = var.subnetwork
    access_config {
      nat_ip = google_compute_address.external_ip.address
    }
  }

  tags = ["coda-daemon"]

  metadata = {
    gce-container-declaration = <<EOF
    spec:
      containers:
        - name: ${var.instance_name}
          image: ${var.mina_image}
          command:
            - /bin/bash
          args:
            - '-c'
            - >-
              ${local.container_command}
          stdin: true
          tty: true
      restartPolicy: Always
    EOF
    google-logging-enabled    = true
  }

  labels = {
    container-vm = data.google_compute_image.coreos.name
  }

  service_account {
    email = var.client_email
    scopes = [
      "https://www.googleapis.com/auth/cloud-platform",
    ]
  }

  depends_on = [ var.subnetwork ]
}
