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

import {
  to = google_compute_firewall.default_allow_rdp
  id = "projects/${var.project_id}/global/firewalls/default-allow-rdp"
}

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

resource "google_compute_firewall" "default_allow_rdp" {
  name          = "default-allow-rdp"
  network       = "default"
  description   = "Allow RDP from anywhere"
  direction     = "INGRESS"
  priority      = 65534
  source_ranges = ["0.0.0.0/0"]

  allow {
    protocol = "tcp"
    ports    = ["3389"]
  }
}
