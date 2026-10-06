output "external_ip" {
  description = "Static external IP of the VM."
  value       = google_compute_address.devops01.address
}

output "ssh_command" {
  description = "SSH with a tunnel to the app."
  value       = "ssh -L 8000:localhost:8000 <user>@${google_compute_address.devops01.address}"
}

output "web_enabled" {
  value = var.enable_web
}
