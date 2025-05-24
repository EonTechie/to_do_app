output "mongodb_vm_ip" {
  value = google_compute_address.mongodb_static_ip.address
}

output "frontend_ip" {
  value = kubernetes_service.frontend.status[0].load_balancer[0].ingress[0].ip
}

output "backend_ip" {
  value = kubernetes_service.backend.status[0].load_balancer[0].ingress[0].ip
} 