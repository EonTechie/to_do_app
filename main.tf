provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# 1. GKE Cluster
resource "google_container_cluster" "primary" {
  name     = "todo-gke"
  location = var.region
  initial_node_count = 2

  node_config {
    machine_type = "e2-medium"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

# 2. Compute Engine VM (MongoDB)
resource "google_compute_instance" "mongo" {
  name         = "mongo-vm"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 20
    }
  }

  network_interface {
    network = "default"
    access_config {}
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    sudo apt-get update
    sudo apt-get install -y gnupg
    wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/debian buster/mongodb-org/6.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org
    sudo sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf
    sudo systemctl enable mongod
    sudo systemctl start mongod
  EOT

  tags = ["mongo"]
}

# 3. Firewall Rule for MongoDB
resource "google_compute_firewall" "mongo" {
  name    = "allow-mongo"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["27017"]
  }

  source_ranges = ["0.0.0.0/0"] # Sadece test için, prod'da daralt!
  target_tags   = ["mongo"]
}

# 4. Cloud Functions için Storage Bucket
resource "google_storage_bucket" "function_bucket" {
  name     = "${var.project_id}-function-bucket"
  location = var.region
  force_destroy = true
}

# 5. Cloud Function Kodlarını Yükle (Örnek: completedTodos)
resource "google_storage_bucket_object" "completedTodos_zip" {
  name   = "completedTodos.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "cloud-function/cfunc2.zip" # Kodunu zip'le ve bu path'e koy
}

resource "google_cloudfunctions_function" "completedTodos" {
  name        = "completedTodos"
  description = "Returns completed todos"
  runtime     = "nodejs20"
  region      = var.region
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.completedTodos_zip.name
  entry_point = "completedTodos"
  trigger_http = true
  available_memory_mb = 256

  environment_variables = {
    MONGO_URI = "mongodb://${google_compute_instance.mongo.network_interface.0.access_config.0.nat_ip}:27017/tododb"
  }
}

# 6. Cloud Scheduler Job (örnek)
resource "google_service_account" "scheduler" {
  account_id   = "scheduler-sa"
  display_name = "Scheduler Service Account"
}

resource "google_project_iam_member" "function_invoker" {
  project = var.project_id
  role    = "roles/cloudfunctions.invoker"
  member  = "serviceAccount:${google_service_account.scheduler.email}"
}

resource "google_cloud_scheduler_job" "notification" {
  name             = "notification"
  description      = "Trigger notification by e-mail 1 day before the task"
  schedule         = "*/5 * * * *"
  time_zone        = "Europe/Moscow"
  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions_function.completedTodos.https_trigger_url
    oidc_token {
      service_account_email = google_service_account.scheduler.email
    }
  }
}

# 7. Output MongoDB IP
output "mongo_ip" {
  value = google_compute_instance.mongo.network_interface[0].access_config[0].nat_ip
}

# 8. Variables
variable "project_id" {}
variable "region"    { default = "us-central1" }
variable "zone"      { default = "us-central1-a" }