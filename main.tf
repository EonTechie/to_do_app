# GCP provider and required versions
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP Region"
  type        = string
}

variable "zone" {
  description = "GCP Zone"
  type        = string
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

data "google_client_config" "default" {}

# 1. VPC Network
resource "google_compute_network" "vpc_network" {
  name = "todo-network"
}

# 2. (SUBNET RESOURCE SİLİNDİ)

# 3. Autopilot GKE Cluster
resource "google_container_cluster" "autopilot_cluster" {
  name     = "vm2-cluster"
  location = var.region
  enable_autopilot = true

  release_channel {
    channel = "REGULAR"
  }

  network    = google_compute_network.vpc_network.name
  subnetwork = "default"

  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }
}


# 4. Kubernetes Provider (Autopilot cluster'a bağlanacak)
provider "kubernetes" {
  alias = "gke"
  host                   = google_container_cluster.autopilot_cluster.endpoint
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.autopilot_cluster.master_auth[0].cluster_ca_certificate)

  # Terraform 1.6+ ile artık böyle geciktirme yapabiliyoruz

}



resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "3000", "4000", "27017"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

# Static IP for MongoDB VM
resource "google_compute_address" "mongodb_static_ip" {
  name    = "mongodb-static-ip"
  region  = var.region
  address = "34.60.227.68"  # Sizin belirttiğiniz IP
}

# MongoDB VM resource'unu güncelle
resource "google_compute_instance" "mongodb_vm" {
  name         = "database-instance"
  machine_type = "e2-highcpu-2"
  zone         = "us-central1-c"
  tags         = ["http-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"  # Ubuntu 20.04 LTS
      size  = 10
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
      nat_ip = google_compute_address.mongodb_static_ip.address  # Static IP'yi kullan
    }
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    apt-get update
    apt-get install -y gnupg curl
    curl -fsSL https://pgp.mongodb.com/server-6.0.asc | gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor
    echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 main" | tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    apt-get update
    apt-get install -y mongodb-org
    systemctl start mongod
    systemctl enable mongod
  EOT
}

# 5. Backend Deployment
resource "kubernetes_deployment" "backend" {
  provider = kubernetes.gke  
    depends_on = [
    google_container_cluster.autopilot_cluster
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
    google_container_cluster.autopilot_cluster
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

# 6. Frontend Deployment
resource "kubernetes_deployment" "frontend" {
  provider = kubernetes.gke  
    depends_on = [
    google_container_cluster.autopilot_cluster, kubernetes_service.backend
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
    google_container_cluster.autopilot_cluster
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

# Cloud Functions kaynak kodlarını saklamak için bucket
resource "google_storage_bucket" "function_bucket" {
  name     = "todo-functions-source-${var.project_id}"
  location = var.region
  uniform_bucket_level_access = true
}

# countCompletedTodos fonksiyonu için zip dosyası
resource "google_storage_bucket_object" "count_completed_todos_zip" {
  name   = "countCompletedTodos.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "./cloud-function/countCompletedTodos.zip"
}

# completedTodos fonksiyonu için zip dosyası
resource "google_storage_bucket_object" "completed_todos_zip" {
  name   = "completedTodos.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "./cloud-function/completedTodos.zip"
}

# notifyDueTasks fonksiyonu için zip dosyası
resource "google_storage_bucket_object" "notify_due_tasks_zip" {
  name   = "notifyDueTasks.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "./cloud-function/notifDueTasks.zip"
}

# Cloud Functions'ları güncelle - MONGO_URI'yi static IP ile güncelle
resource "google_cloudfunctions_function" "count_completed_todos" {
  name        = "countCompletedTodos"
  description = "Counts completed todos"
  runtime     = "nodejs18"
  entry_point = "countCompletedTodos"
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.count_completed_todos_zip.name
  trigger_http = true
  available_memory_mb   = 1024
  environment_variables = {
    MONGO_URI = "mongodb://${google_compute_address.mongodb_static_ip.address}:27017/tododb"
  }

  min_instances = 1
  max_instances = 10
  ingress_settings = "ALLOW_ALL"
  timeout = 60

  labels = {
    "deployment-tool" = "terraform"
  }
}

resource "google_cloudfunctions_function" "completed_todos" {
  name        = "completedTodos"
  description = "Handles completed todos"
  runtime     = "nodejs18"
  entry_point = "completedTodos"
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.completed_todos_zip.name
  trigger_http = true
  available_memory_mb   = 1024
  environment_variables = {
    MONGO_URI = "mongodb://${google_compute_address.mongodb_static_ip.address}:27017/tododb"
  }

  min_instances = 1
  max_instances = 10
  ingress_settings = "ALLOW_ALL"
  timeout = 60

  labels = {
    "deployment-tool" = "terraform"
  }
}

resource "google_cloudfunctions_function" "notify_due_tasks" {
  name        = "notifyDueTasks"
  description = "Notifies about due tasks"
  runtime     = "nodejs18"
  entry_point = "notifyDueTasks"
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.notify_due_tasks_zip.name
  trigger_http = true
  available_memory_mb   = 1024
  environment_variables = {
    MONGO_URI = "mongodb://${google_compute_address.mongodb_static_ip.address}:27017/tododb"
    EMAIL_USER = "your-email@gmail.com"
    EMAIL_PASS = "your-app-password"
    NOTIFY_EMAIL = "recipient@example.com"
  }

  min_instances = 1
  max_instances = 10
  ingress_settings = "ALLOW_ALL"
  timeout = 60

  labels = {
    "deployment-tool" = "terraform"
  }
}

output "mongodb_vm_ip" {
  value = google_compute_address.mongodb_static_ip.address
}

output "frontend_ip" {
  value = kubernetes_service.frontend.status[0].load_balancer[0].ingress[0].ip
}

output "backend_ip" {
  value = kubernetes_service.backend.status[0].load_balancer[0].ingress[0].ip
}
