# main.tf


# Configure the Google Cloud provider
provider "google" {
  project = var.project_id
  region  = var.region # Use a variable for region
}


## API Enablement

# Enables the Cloud Pub/Sub API
resource "google_project_service" "pubsub_api" {
  project            = var.project_id
  service            = "pubsub.googleapis.com"
  disable_on_destroy = false
}

# Enables the BigQuery API
resource "google_project_service" "bigquery_api" {
  project            = var.project_id
  service            = "bigquery.googleapis.com"
  disable_on_destroy = false
}

# Enables the BigQuery Connection API, required for BigLake connections
resource "google_project_service" "bigquery_connection_api" {
  project            = var.project_id
  service            = "bigqueryconnection.googleapis.com"
  disable_on_destroy = false
}

# Enables the Cloud Storage API
resource "google_project_service" "cloud_storage_api" {
  project            = var.project_id
  service            = "storage.googleapis.com"
  disable_on_destroy = false
}

# Enables the Cloud Resource Manager API
resource "google_project_service" "cloudresourcemanager_api" {
  project            = var.project_id
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}


## BigQuery Dataset and Dummy Table (Managed by Terraform now)

resource "google_bigquery_dataset" "orders_dataset" {
  project       = var.project_id
  dataset_id    = "orders"
  friendly_name = "Orders Processing Data"
  description   = "Dataset for order event data, including Iceberg tables."
  location      = var.region # Ensure location matches GCS bucket and Pub/Sub

  depends_on = [google_project_service.bigquery_api]
}


## Creating native table first to attach the subscription to it

resource "google_bigquery_table" "order_event_iceberg" { 
  project             = var.project_id
  dataset_id          = google_bigquery_dataset.orders_dataset.dataset_id
  table_id            = "order_event_iceberg" # Must match the SQL table_id
  deletion_protection = false # Set to false for demo purposes to allow replace/destroy

  schema = jsonencode([
    {
      "name": "order_id",
      "type": "STRING",
      "mode": "NULLABLE"
    },
    {
      "name": "customer_id",
      "type": "STRING",
      "mode": "NULLABLE"
    },
    {
      "name": "items",
      "type": "RECORD",
      "mode": "REPEATED",
      "fields": [
        {"name": "item_id", "type": "STRING", "mode": "NULLABLE"},
        {"name": "product_name", "type": "STRING", "mode": "NULLABLE"},
        {"name": "quantity", "type": "INTEGER", "mode": "NULLABLE"},
        {"name": "unit_price", "type": "FLOAT", "mode": "NULLABLE"}
      ]
    },
    {
      "name": "total_amount",
      "type": "FLOAT",
      "mode": "NULLABLE"
    },
    {
      "name": "currency",
      "type": "STRING",
      "mode": "NULLABLE"
    },
    {
      "name": "order_timestamp", # Protobuf int64 timestamp (milliseconds) -> BigQuery INTEGER
      "type": "INTEGER",
      "mode": "NULLABLE"
    }
  ])
  depends_on = [google_bigquery_dataset.orders_dataset]
}


## Pub/Sub Resources

# Creates the Pub/Sub schema based on the Protobuf definition
resource "google_pubsub_schema" "order_schema" {
  project     = var.project_id
  name        = "order-processing-schema"
  type        = "PROTOCOL_BUFFER"
  definition  = file("${path.module}/order.proto") # Directly read the file content
  depends_on  = [google_project_service.pubsub_api]
}

# Resource to generate a random suffix for the Pub/Sub topic name
resource "random_id" "topic_suffix" {
  byte_length = 4 # Generates 8 hex characters
}

# Creates the Pub/Sub topic with schema enforcement
resource "google_pubsub_topic" "order_topic" {
  project     = var.project_id
  name        = "order-events-${random_id.topic_suffix.hex}" # Dynamic topic name

  schema_settings {
    schema      = google_pubsub_schema.order_schema.id
    encoding    = "JSON" # Confirmed: Using JSON encoding for Protobuf messages
  }

  depends_on = [google_pubsub_schema.order_schema]
}

# Creates a Pub/Sub subscription pushing to BigQuery native table for now
resource "google_pubsub_subscription" "order_subscription" {
  project            = var.project_id
  name               = "order-events-subscription-${random_id.topic_suffix.hex}-bq" # Link subscription to topic suffix and indicate BQ destination
  topic              = google_pubsub_topic.order_topic.id

  bigquery_config {
    table               = "${google_bigquery_table.order_event_iceberg.project}.${google_bigquery_table.order_event_iceberg.dataset_id}.${google_bigquery_table.order_event_iceberg.table_id}"
    use_table_schema    = true  # Use the BigQuery table's explicit schema
    write_metadata      = false  # Optional: include Pub/Sub message metadata in the BigQuery table
  }

  depends_on = [
    google_pubsub_topic.order_topic,
    google_bigquery_table.order_event_iceberg # Explicitly depend on the BQ table being created
  ]
}


## GCS Bucket for Iceberg Table Storage

# Resource to generate a random suffix for the bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4 # Generates 8 hex characters
}

resource "google_storage_bucket" "iceberg_storage_bucket" {
  project                     = var.project_id
  # Bucket names must be globally unique and can include lowercase letters, numbers, hyphens, and dots.
  # Using random_id to ensure uniqueness.
  name                        = "${var.project_id}-${random_id.bucket_suffix.hex}"
  location                    = var.region
  uniform_bucket_level_access = true
  force_destroy               = true # Allows bucket to be destroyed even if not empty (useful for demos)

  depends_on = [google_project_service.cloud_storage_api]
}


## Outputs

output "pubsub_topic_name" {
  value       = google_pubsub_topic.order_topic.name
  description = "The name of the Pub/Sub topic."
}

output "pubsub_schema_id" {
  value       = google_pubsub_schema.order_schema.id
  description = "The ID of the Pub/Sub schema."
}

output "pubsub_subscription_name" {
  value       = google_pubsub_subscription.order_subscription.name
  description = "The name of the Pub/Sub subscription."
}

output "gcs_bucket_name" {
  value       = google_storage_bucket.iceberg_storage_bucket.name
  description = "Name of the GCS bucket for Iceberg storage."
}

output "bigquery_dataset_id" {
  value       = google_bigquery_dataset.orders_dataset.dataset_id # Now derived from Terraform resource
  description = "ID of the BigQuery dataset."
}