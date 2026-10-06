variable "project_id" {
  description = "GCP project ID."
  type        = string
}

variable "region" {
  description = "GCP region of the VM."
  type        = string
  default     = "europe-west2"
}

variable "zone" {
  description = "GCP zone of the VM."
  type        = string
  default     = "europe-west2-b"
}

variable "instance_name" {
  description = "Name of the existing VM to bring under management."
  type        = string
  default     = "gcp-devops01"
}

variable "machine_type" {
  description = "VM size. e2-medium = 2 vCPU / 4 GB."
  type        = string
  default     = "e2-medium"
}

variable "static_ip" {
  description = "The VM's current external IP, promoted to a reserved static address so it never changes."
  type        = string
}

variable "web_source_ranges" {
  description = "CIDRs allowed to reach HTTP/HTTPS (used from phase 6, when TLS is in place)."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_web" {
  description = "Open ports 80/443 to the VM. Keep false until TLS is configured (phase 6)."
  type        = bool
  default     = false
}
