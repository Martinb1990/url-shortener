terraform {
  required_version = ">= 1.9"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.5"
    }
  }

  # Remote state in a versioned GCS bucket (created by bootstrap-state.sh).
  # The bucket name is passed at init time: tofu init -backend-config=backend.hcl
  backend "gcs" {
    prefix = "url-shortener/infra"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  default_labels = {
    project    = "url-shortener"
    managed-by = "opentofu"
  }
}
