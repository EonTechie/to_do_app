data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.default.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.default.master_auth[0].cluster_ca_certificate)

  ignore_annotations = [
    "^autopilot\\.gke\\.io\\/.*",
    "^cloud\\.google\\.com\\/.*"
  ]
}

resource "kubernetes_deployment" "backend" {

  depends_on = [
    google_container_cluster.default
  ]
  metadata {
    name = "backend"
    labels = {
      app = "backend"
    }
    annotations = {
      "cloud.google.com/load-balancer-ipv4-address" = "backend-static-ip"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "backend"
      }
    }
    template {
      metadata {
        labels = {
          app = "backend"
        }
      }
      spec {
        container {
          name  = "backend"
          image = "docker.io/filizyildizfi88/todo-backend:latest"
          port {
            container_port = 4000
          }
          env {
            name  = "MONGO_URI"
            value = "mongodb://${google_compute_address.mongodb_static_ip.address}:27017/tododb"
          }
          resources {
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
            requests = {
              memory = "256Mi"
              cpu    = "250m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "backend" {
  depends_on = [
    google_container_cluster.default
  ]
  metadata {
    name = "backend"
  }
  spec {
    selector = {
      app = "backend"
    }
    type = "LoadBalancer"
    port {
      port        = 4000
      target_port = 4000
    }
  }
  wait_for_load_balancer = true
}

resource "kubernetes_deployment" "frontend" {

  depends_on = [
    google_container_cluster.default, kubernetes_service.backend
  ]
  metadata {
    name = "frontend"
    labels = {
      app = "frontend"
    }
  }
  spec {
    replicas = 2
    selector {
      match_labels = {
        app = "frontend"
      }
    }
    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }
      spec {
        container {
          name  = "frontend"
          image = "docker.io/filizyildizfi88/todo-frontend:latest"
          port {
            container_port = 3000
          }
          env {
            name  = "API_URL"
            value = "http://${kubernetes_service.backend.status[0].load_balancer[0].ingress[0].ip}:4000/todos"
          }
          resources {
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
            requests = {
              memory = "256Mi"
              cpu    = "250m"
            }
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "frontend" {
  depends_on = [
    google_container_cluster.default
  ]
  metadata {
    name = "frontend"
  }
  spec {
    selector = {
      app = "frontend"
    }
    type = "LoadBalancer"
    port {
      port        = 3000
      target_port = 3000
    }
  }
} 