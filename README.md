# To-Do App Terraform Deployment

This repository contains Terraform configurations to deploy a complete To-Do application on Google Cloud Platform (GCP).

## Prerequisites

1. Install [Terraform](https://www.terraform.io/downloads.html)
2. Install [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
3. Create a GCP project and enable billing
4. Enable required APIs:
   - Cloud Run API
   - Cloud Functions API
   - Cloud SQL Admin API
   - Container Registry API
   - Cloud Storage API
   - Kubernetes Engine API

## Deployment Steps

1. Initialize Terraform:
```bash
terraform init
```

2. Review the planned changes:
```bash
terraform plan
```

3. Apply the configuration:
```bash
terraform apply
```

4. After successful deployment, you'll see the following outputs:
   - Backend URL (Cloud Run service)
   - Frontend URL (Cloud Storage bucket)

## Architecture

The deployment creates the following resources:

- VPC Network and Subnet
- Cloud SQL MySQL instance
- GKE Cluster with Node Pool
- Cloud Storage Bucket for Frontend
- Cloud Run Service for Backend
- Three Cloud Functions:
  - countCompletedTodos
  - completedTodos
  - notifyDueTasks

## Cleanup

To destroy all created resources:
```bash
terraform destroy
```

## Notes

- The configuration uses the following default values:
  - Region: us-central1
  - Zone: us-central1-a
  - Database: MySQL 8.0
  - GKE Node Pool: 2 nodes of type e2-medium

- Make sure to update the `terraform.tfvars` file with your GCP project ID before deployment. 