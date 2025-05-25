resource "google_storage_bucket" "function_bucket" {
  name     = "todo-functions-source-${var.project_id}"
  location = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_object" "count_completed_todos_zip" {
  name   = "countCompletedTodos.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "./cloud-function/countCompletedTodos.zip"
}

resource "google_storage_bucket_object" "completed_todos_zip" {
  name   = "completedTodos.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "./cloud-function/completedTodos.zip"
}

resource "google_storage_bucket_object" "notify_due_tasks_zip" {
  name   = "notifyDueTasks.zip"
  bucket = google_storage_bucket.function_bucket.name
  source = "./cloud-function/notifDueTasks.zip"
}

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
    EMAIL_USER = "remindertodoapp@gmail.com"
    EMAIL_PASS = "raddzyhrpqmcmqwp"
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