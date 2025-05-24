# To-Do App Terraform Deployment (MongoDB Version)

This repository contains Terraform configurations to deploy a complete To-Do application on Google Cloud Platform (GCP) using **MongoDB** as the database.

## Prerequisites

1. Install [Terraform](https://www.terraform.io/downloads.html)
2. Install [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
3. Create a GCP project and enable billing
4. Enable required APIs:
   - Kubernetes Engine API
   - Compute Engine API
   - Cloud Functions API
   - Cloud Storage API
   - Container Registry API
5. Docker (for building images)

## Project Structure

- **main.tf**: GCP network, subnetwork, GKE cluster, firewall, static IP, and MongoDB VM resources
- **network.tf**: (if present) Network and firewall resources
- **k8s-deployment.tf**: Kubernetes deployments and services for backend and frontend
- **functions.tf**: Google Cloud Functions and related storage resources
- **outputs.tf**: Terraform output variables
- **variables.tf**: All variable definitions
- **terraform.tfvars**: Your project-specific variable values
- **backend/**: Node.js backend source code (uses MongoDB)
- **frontend/**: React frontend source code
- **cloud-function/**: Source code for Google Cloud Functions (Node.js, uses MongoDB)

## Deployment Steps

1. **Configure Variables**
   - Edit `terraform.tfvars` and set your `project_id`, `region`, and `zone`.

2. **Initialize Terraform**
   ```sh
   terraform init
   ```

3. **Review the planned changes**
   ```sh
   terraform plan
   ```

4. **Apply the configuration**
   ```sh
   terraform apply
   ```

5. **After successful deployment, outputs will include:**
   - MongoDB VM IP address
   - Backend Service IP
   - Frontend Service IP

## Architecture

- **VPC Network and Subnet**
- **GKE Autopilot Cluster** (for running backend and frontend containers)
- **Compute Engine VM** (Debian 11, runs MongoDB)
- **Static IP** (for MongoDB VM)
- **Kubernetes Deployments & Services**
  - Backend (Node.js, connects to MongoDB)
  - Frontend (React)
- **Google Cloud Functions** (Node.js, connects to MongoDB)
- **Cloud Storage Bucket** (for function source zips)

## MongoDB Details
- MongoDB is installed on a Compute Engine VM (Debian 11) with a static external IP.
- All backend and cloud functions connect to MongoDB using this static IP.
- MongoDB installation and startup are automated via VM startup script.

## Cleanup
To destroy all created resources:
```sh
terraform destroy
```

## Notes
- The configuration uses the following default values:
  - Region: us-central1
  - Zone: us-central1-c
  - Database: **MongoDB 6.0** (not MySQL)
  - GKE Node Pool: Autopilot
- Make sure to update the `terraform.tfvars` file with your GCP project ID before deployment.
- All application data is stored in MongoDB, not MySQL.

## Quick Start for Developers

- **Backend**: Node.js app in `/backend`, uses `MONGO_URI` env variable.
- **Frontend**: React app in `/frontend`, connects to backend via service IP.
- **Cloud Functions**: Node.js, source in `/cloud-function`, uses `MONGO_URI`.

---

> This project is fully containerized and cloud-native, using MongoDB as the primary database for all services. 