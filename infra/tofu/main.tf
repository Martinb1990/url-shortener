# The VM already exists (created by hand before this project), so it is
# imported into state rather than created. After the first apply these
# import blocks are no-ops and can stay as documentation.

import {
  to = google_compute_instance.devops01
  id = "projects/${var.project_id}/zones/${var.zone}/instances/${var.instance_name}"
}

# ---------------------------------------------------------------- network

# Reserving the VM's current ephemeral IP as static keeps the address
# (and the SSH config pointing at it) stable across VM stop/start.
resource "google_compute_address" "devops01" {
  name         = "${var.instance_name}-ip"
  address      = var.static_ip
  address_type = "EXTERNAL"
  network_tier = "PREMIUM"
  description  = "Static external IP for ${var.instance_name}"

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_firewall" "web" {
  count = var.enable_web ? 1 : 0

  name          = "allow-web-url-shortener"
  network       = "default"
  description   = "HTTP/HTTPS to the URL shortener ingress"
  direction     = "INGRESS"
  source_ranges = var.web_source_ranges
  target_tags   = ["web"]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}

# --------------------------------------------------------------------- vm

# Accepted risk: the VM needs a public IP. It is a single host reached over
# SSH (key-only, server-baseline hardened) and will serve HTTPS in phase 6;
# a bastion or Cloud NAT + load balancer would add cost this project avoids.
#trivy:ignore:GCP-0031
resource "google_compute_instance" "devops01" {
  name                = var.instance_name
  machine_type        = var.machine_type
  zone                = var.zone
  deletion_protection = true

  # Changing machine_type requires a stop/start; allow tofu to do it.
  allow_stopping_for_update = true

  # Set explicitly to match the VM: leaving it unset (null) vs the API's
  # "NONE" is treated as a change that forces replacement.
  key_revocation_action_type = "NONE"

  tags = var.enable_web ? ["web"] : []

  boot_disk {
    auto_delete = true
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-minimal-2604-lts-amd64"
    }
  }

  network_interface {
    network = "default"
    access_config {
      nat_ip       = google_compute_address.devops01.address
      network_tier = "PREMIUM"
    }
  }

  # Matches the VM as created. Secure Boot needs a stop/start to enable;
  # tracked as an accepted MEDIUM finding (see infra/README.md).
  shielded_instance_config {
    enable_secure_boot          = false
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      # Set once at creation; changing it would force a rebuild of an imported VM.
      boot_disk[0].initialize_params,
      # SSH keys and startup metadata are managed outside tofu.
      metadata,
    ]
  }
}
