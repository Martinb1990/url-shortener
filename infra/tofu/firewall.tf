# GCP's default-network firewall rules, created automatically with the
# project and imported here so every change to them goes through a PR.

import {
  to = google_compute_firewall.default_allow_ssh
  id = "projects/${var.project_id}/global/firewalls/default-allow-ssh"
}

import {
  to = google_compute_firewall.default_allow_icmp
  id = "projects/${var.project_id}/global/firewalls/default-allow-icmp"
}

import {
  to = google_compute_firewall.default_allow_internal
  id = "projects/${var.project_id}/global/firewalls/default-allow-internal"
}

# Accepted risk (Trivy GCP-0027): SSH is reachable from any IP. Logins are
# key-only and server-baseline hardened (fail2ban-style brute-force
# protection, MaxAuthTries). Restricting the source (home IP, or IAP's
# 35.235.240.0/20 with `gcloud compute ssh --tunnel-through-iap`) is the
# stronger option; see infra/README.md.
#trivy:ignore:GCP-0027
resource "google_compute_firewall" "default_allow_ssh" {
  name          = "default-allow-ssh"
  network       = "default"
  description   = "Allow SSH from anywhere"
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

# Accepted risk (Trivy GCP-0027): ICMP from anywhere (ping, path-MTU
# discovery); no data exposure.
#trivy:ignore:GCP-0027
resource "google_compute_firewall" "default_allow_icmp" {
  name          = "default-allow-icmp"
  network       = "default"
  description   = "Allow ICMP from anywhere"
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "default_allow_internal" {
  name          = "default-allow-internal"
  network       = "default"
  description   = "Allow internal traffic on the default network"
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["10.128.0.0/9"]

  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }
  allow {
    protocol = "icmp"
  }
}

# default-allow-rdp (tcp:3389 from 0.0.0.0/0) was deleted through this file:
# it opened Windows Remote Desktop to the internet on a Linux VM.
