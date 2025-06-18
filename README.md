This self-developed project demonstrates end-to-end cloud-native architecture, integrating container orchestration, serverless design, infrastructure-as-code, and scalable performance evaluation on Google Cloud. All configurations, monitoring setups, and deployment scripts are included and reproducible.

## MongoDB VM and Static IP Setup

To run this project from scratch, you must manually create a MongoDB VM with a static IP and open the required firewall ports.

### 1. Reserve a Static IP for MongoDB VM
```sh
gcloud compute addresses create mongodb-static-ip --region=us-central1
```

### 2. Create a Compute Engine VM for MongoDB
```sh
gcloud compute instances create database-instance \
  --zone=us-central1-c \
  --machine-type=e2-highcpu-2 \
  --image-family=debian-11 \
  --image-project=debian-cloud \
  --tags=http-server \
  --boot-disk-size=10GB \
  --address=$(gcloud compute addresses describe mongodb-static-ip --region=us-central1 --format='get(address)')
```

### 3. Open Firewall Ports
To allow HTTP, HTTPS, backend, frontend, and MongoDB access, create the following firewall rule:
```sh
gcloud compute firewall-rules create allow-http \
  --network=default \
  --allow tcp:80,tcp:443,tcp:3000,tcp:4000,tcp:27017 \
  --source-ranges=0.0.0.0/0 \
  --target-tags=http-server
```
This single rule opens all necessary ports for your application and database.

### 4. SSH into the VM and Install MongoDB
```sh
gcloud compute ssh database-instance --zone=us-central1-c
```
Then, inside the VM:
```sh
sudo apt-get update
sudo apt-get install -y gnupg curl
curl -fsSL https://pgp.mongodb.com/server-6.0.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-6.0.gpg --dearmor
echo "deb [ signed-by=/usr/share/keyrings/mongodb-server-6.0.gpg ] https://repo.mongodb.org/apt/debian buster/mongodb-org/6.0 main" | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list
sudo apt-get update
sudo apt-get install -y mongodb-org
sudo systemctl start mongod
sudo systemctl enable mongod
```

### 5. Get the Static IP Address
```sh
gcloud compute addresses describe mongodb-static-ip --region=us-central1 --format='get(address)'
```
Use this IP in your backend `.env` file:
```
MONGO_URI=mongodb://<STATIC_IP>:27017/tododb
```

---

## Kubernetes Cluster Requirements & Creation

- We recommend a GKE Autopilot cluster in `us-central1`, but any GKE or compatible Kubernetes cluster will work.
- Minimum: 2 vCPUs, 2GB RAM per node (for production).
- Example cluster creation:
  ```sh
  gcloud container clusters create-auto <your-cluster-name> --region=us-central1
  ```
- After creation, get credentials:
  ```sh
  gcloud container clusters get-credentials <your-cluster-name> --region=us-central1
  ```

> **Note:** You can use other regions, zones, or cluster types as long as you update the configs accordingly.

---

## Google Cloud Setup & Image Push

Before deploying your application to Google Kubernetes Engine (GKE), make sure you are authenticated with Google Cloud, your project and cluster are set, and your Docker images are built and pushed to your own registry.

### 1. Authenticate with Google Cloud and Set Project

```sh
# Log in to your Google Cloud account
gcloud auth login

# Set your active account (replace with your email)
gcloud config set account <your-gcp-account>

# Set your active project (replace with your project ID)
gcloud config set project <your-gcp-project-id>
```

### 2. Get GKE Cluster Credentials

```sh
# Replace with your cluster name and region/zone
gcloud container clusters get-credentials <your-cluster-name> --region <your-region>
```

### 3. Build and Push Backend Docker Image

```sh
cd backend
docker build -t <your-registry>/todo-backend:latest .
docker push <your-registry>/todo-backend:latest
cd ..
```

> **Note:**  
> Replace `<your-gcp-account>`, `<your-gcp-project-id>`, `<your-cluster-name>`, `<your-region>`, and `<your-registry>` with your own values.  
> You must push your images to a registry (e.g., Google Container Registry or Artifact Registry) that your GKE cluster can access.



## Backend Environment File

In your `/backend` directory, create a file named `.env`:
```
MONGO_URI=mongodb://<STATIC_IP>:27017/tododb
```
Replace `<STATIC_IP>` with the static IP you reserved for your MongoDB VM.

---
> **Note:**
You should not build and push the frontend Docker image at this stage. The frontend must be configured to use the backend's external IP address, which is only available after the backend is deployed and its service is exposed.
Therefore, please proceed with the manual setup steps below to deploy the backend first, obtain its external IP, and then update the frontend configuration accordingly. 

## General Note

All these steps are required for a fresh Google Cloud project. The project is portable to other clusters/VMs if you adapt the configs and environment variables accordingly.

## Manual Deployment Steps (First Time Setup)

> **Important:**
> Do **not** build and push the frontend Docker image until you have deployed the backend and obtained its external IP address. The frontend must be configured with the backend's IP before building the image.

1. **Backend Deployment**
   ```sh
   kubectl apply -f k8s/backend-deployment.yaml
   kubectl get svc backend  # Note the EXTERNAL-IP
   ```

2. **Frontend Configuration**
   - Update `frontend/src/App.js` with the backend's EXTERNAL-IP:
     ```javascript
     const API_URL = 'http://<BACKEND-EXTERNAL-IP>:4000/todos';
     ```

3. **Frontend Deployment**
   ```sh
   # Build and push frontend image
   docker build -t your-registry/todo-frontend:latest ./frontend
   docker push your-registry/todo-frontend:latest
   
   # Deploy frontend
   kubectl apply -f k8s/frontend-deployment.yaml
   kubectl get svc frontend  # Note the EXTERNAL-IP
   ```

4. **Access Application**
   - Open browser and navigate to: `http://<FRONTEND-EXTERNAL-IP>:3000`

## Google Cloud Functions Manual Deployment

To deploy the Cloud Functions in the `cloud-function` directory, follow these steps for each function (e.g., `countCompletedTodos`, `completedTodos`, `notifyTasks`):

### 1. Zip the Function Source

```sh
cd cloud-function/<function-folder>
zip -r ../<function-name>.zip .
cd ../..
```

### 2. Deploy the Function

For `notifyTasks`, you need to set additional environment variables for email notifications. Example:

```sh
gcloud functions deploy notifyTasks \
  --runtime nodejs18 \
  --trigger-http \
  --entry-point notifyTasks \
  --memory 256MB \
  --region <your-region> \
  --set-env-vars MONGO_URI=mongodb://<STATIC_IP>:27017/tododb,EMAIL_USER=remindertodoapp@gmail.com,EMAIL_PASS=raddzyhrpqmcmqwp,NOTIFY_EMAIL=<recipient1@example.com>,<recipient2@example.com> \
  --min-instances=0 \
  --max-instances=1 \
  --concurrency=1
```

- **MONGO_URI:** Your MongoDB connection string (use your VM's static IP)
- **EMAIL_USER:** The sender email address (`remindertodoapp@gmail.com`)
- **EMAIL_PASS:** The app password for the sender email (`raddzyhrpqmcmqwp`)
- **NOTIFY_EMAIL:** The recipient(s) who will receive the notification emails (comma-separated for multiple addresses)

> **Note:**
> - You can set `NOTIFY_EMAIL` to any email address you want to receive notifications.
> - The sender email (`remindertodoapp@gmail.com`) and its app password (`raddzyhrpqmcmqwp`) must be valid and able to send emails via SMTP.
> - For other functions, only `MONGO_URI` is required as an environment variable.

### Example for `countCompletedTodos`:

```sh
gcloud functions deploy countCompletedTodos \
  --runtime nodejs18 \
  --trigger-http \
  --entry-point countCompletedTodos \
  --memory 512MB \
  --region <your-region> \
  --set-env-vars MONGO_URI=mongodb://<STATIC_IP>:27017/tododb
```

### Example for `completedTodos`:

```sh
gcloud functions deploy completedTodos \
  --runtime nodejs18 \
  --trigger-http \
  --entry-point completedTodos \
  --memory 512MB \
  --region <your-region> \
  --set-env-vars MONGO_URI=mongodb://<STATIC_IP>:27017/tododb
```

## Branch Information

- **main**: Contains our initial setup and basic configuration
- **optimization**: Contains our second configuration with performance improvements
- **optimization2**: Contains our latest configurations and optimizations

> Note: In addition to these three branches, we had many other configurations and performed deployments and tests with them. We did not create a separate branch for every configuration. We ran more than 5 hours of Locust performance tests and frequently changed and tested different configs. We also actively used Google Cloud Monitoring and Observability dashboards during our work.

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

> **Important:**
> The provided Terraform configuration cannot create a GKE cluster from scratch if one does not already exist. You must create the cluster manually (via Google Cloud Console or CLI) before running `terraform apply`. Terraform can only manage resources inside an existing cluster.

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

## Google Cloud Billing Details

Below are our latest Google Cloud billing details:

| Service                                   | Cost      |
|--------------------------------------------|-----------|
| Cloud Run                                 | ₺0.04     |
| Artifact Registry                         | ₺0.00     |
| Cloud Monitoring                          | ₺70.64    |
| VM Manager                                | ₺13.37    |
| Compute Engine                            | ₺878.23   |
| Container Registry Vulnerability Scanning | ₺2,068.32 |
| Kubernetes Engine                         | ₺1,618.16 |
| Networking                                | ₺291.45   |
| Cloud Run Functions                       | ₺744.49   |

**Total Google Cloud Cost:** ₺5,684.70

