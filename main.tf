terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 4.0"
    }
  }
}

provider "google" {
  project = "extreme-wind-457613-b2"
  region  = "us-central1"
  zone    = "us-central1-a"
}

# VPC Network
resource "google_compute_network" "vpc_network" {
  name = "todo-network"
}

# Firewall rules
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http"
  network = google_compute_network.vpc_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "3000", "4000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server"]
}

# MongoDB VM Instance
resource "google_compute_instance" "mongodb" {
  name         = "mongodb-instance"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  tags = ["http-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = 20
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    # MongoDB kurulumu
    wget -qO - https://www.mongodb.org/static/pgp/server-6.0.asc | sudo apt-key add -
    echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/6.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
    sudo apt-get update
    sudo apt-get install -y mongodb-org
    sudo systemctl start mongod
    sudo systemctl enable mongod
  SCRIPT
}

# Backend VM Instance
resource "google_compute_instance" "backend" {
  name         = "backend-instance"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  tags = ["http-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = 20
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    # Node.js kurulumu
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs

    # Uygulama kurulumu
    git clone https://github.com/your-repo/to-do-app.git
    cd to-do-app/backend
    npm install
    npm start
  SCRIPT
}

# Frontend VM Instance
resource "google_compute_instance" "frontend" {
  name         = "frontend-instance"
  machine_type = "e2-medium"
  zone         = "us-central1-a"

  tags = ["http-server"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2004-lts"
      size  = 20
    }
  }

  network_interface {
    network = google_compute_network.vpc_network.name
    access_config {
      // Ephemeral public IP
    }
  }

  metadata_startup_script = <<-SCRIPT
    #!/bin/bash
    # Node.js kurulumu
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs

    # Uygulama kurulumu
    git clone https://github.com/your-repo/to-do-app.git
    cd to-do-app/frontend
    npm install
    npm start
  SCRIPT
}

# Storage bucket for Cloud Functions
resource "google_storage_bucket" "function_bucket" {
  name     = "extreme-wind-457613-b2-function-bucket"
  location = "us-central1"
}

# Cloud Functions source code upload
resource "google_storage_bucket_object" "function1_zip" {
  name   = "function1.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "../function1.zip"
}

resource "google_storage_bucket_object" "function2_zip" {
  name   = "function2.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "../function2.zip"
}

resource "google_storage_bucket_object" "function3_zip" {
  name   = "function3.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "../function3.zip"
}

# Cloud Functions
resource "google_cloudfunctions_function" "count_completed_todos" {
  name        = "count-completed-todos"
  description = "Count completed todos"
  runtime     = "nodejs18"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.function1_zip.name
  trigger_http          = true
  entry_point           = "countCompletedTodos"

  environment_variables = {
    MONGO_URI = "mongodb://${google_compute_instance.mongodb.network_interface[0].access_config[0].nat_ip}:27017/tododb"
  }
}

resource "google_cloudfunctions_function" "completed_todos" {
  name        = "completed-todos"
  description = "Get completed todos"
  runtime     = "nodejs18"

  available_memory_mb   = 256
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.function2_zip.name
  trigger_http          = true
  entry_point           = "completedTodos"

  environment_variables = {
    MONGO_URI = "mongodb://${google_compute_instance.mongodb.network_interface[0].access_config[0].nat_ip}:27017/tododb"
  }
}

# Output values
output "mongodb_ip" {
  value = google_compute_instance.mongodb.network_interface[0].access_config[0].nat_ip
}

output "backend_ip" {
  value = google_compute_instance.backend.network_interface[0].access_config[0].nat_ip
}

output "frontend_ip" {
  value = google_compute_instance.frontend.network_interface[0].access_config[0].nat_ip
} 