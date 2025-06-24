#!/bin/bash

# Function to display script usage
usage() {
  echo "Usage: $0 --project_id <YOUR_GCP_PROJECT_ID> --region <GCP_REGION>"
  echo "  --project_id: Your Google Cloud Project ID."
  echo "  --region: The GCP region for resource deployment (e.g., europe-west1)."
  exit 1
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --project_id)
      PROJECT_ID="$2"
      shift
      ;;
    --region)
      REGION="$2"
      shift

      ;;
    *)
      echo "Unknown parameter: $1"
      usage
      ;;
  esac
  shift
done

# Check if project_id and region are provided
if [ -z "$PROJECT_ID" ]; then
  read -p "Enter your Google Cloud Project ID: " PROJECT_ID
  if [ -z "$PROJECT_ID" ]; then
    echo "Project ID cannot be empty. Exiting."
    exit 1
  fi
fi

if [ -z "$REGION" ]; then
  read -p "Enter the GCP region (e.g., europe-west1): " REGION
  if [ -z "$REGION" ]; then
    echo "Region cannot be empty. Exiting."
    exit 1
  fi
fi

echo "--- Starting Deployment ---"
echo "Project ID: $PROJECT_ID"
echo "Region: $REGION"

# ADDED: Explicitly enable the Cloud Pub/Sub API using gcloud
echo "Enabling Cloud Pub/Sub API (pubsub.googleapis.com)..."
gcloud services enable pubsub.googleapis.com --project="$PROJECT_ID"

if [ $? -ne 0 ]; then
  echo "Failed to enable Cloud Pub/Sub API. Exiting."
  exit 1
fi
echo "Cloud Pub/Sub API enabled."


# 1. Initialize Terraform (only once)
echo "Initializing Terraform..."
terraform init

if [ $? -ne 0 ]; then
  echo "Terraform initialization failed. Exiting."
  exit 1
fi

# Grant BigQuery Data Editor role to the Google-managed Pub/Sub service account
echo ""
echo "--- Granting BigQuery Data Editor role to Pub/Sub Service Account ---"

# Get the Project Number from the Project ID
PROJECT_NUMBER=$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")
if [ -z "$PROJECT_NUMBER" ]; then
  echo "Failed to retrieve Project Number for Project ID: $PROJECT_ID. Exiting."
  exit 1
fi

# Construct the Google-managed Pub/Sub service account email
PUBSUB_SERVICE_ACCOUNT="service-${PROJECT_NUMBER}@gcp-sa-pubsub.iam.gserviceaccount.com"

echo "Ensuring Pub/Sub service account ($PUBSUB_SERVICE_ACCOUNT) can write to BigQuery..."

# Grant the BigQuery Data Editor role
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$PUBSUB_SERVICE_ACCOUNT" \
    --role="roles/bigquery.dataEditor" \
    --condition=None # Use --condition=None if no conditional binding is desired

if [ $? -ne 0 ]; then
  echo "Failed to grant BigQuery Data Editor role to Pub/Sub service account. Please check your IAM permissions for the caller of this script. Exiting."
  exit 1
fi

echo "BigQuery Data Editor role granted to Pub/Sub Service Account successfully."
echo ""


# --- Phase 1: Create All Terraform Resources ---
# This phase creates: APIs, GCS Bucket, BigQuery Dataset, Native BigQuery Table,
# Pub/Sub Schema, Pub/Sub Topic, and Pub/Sub Subscription (linked to the native BQ table).
echo ""
echo "--- Phase 1: Creating All Terraform-Managed Infrastructure ---"

# We no longer use -target for all resources, as we want them all to apply in one go.
# Terraform's dependency graph will handle the order within this apply.

# Run Terraform plan for all resources
echo "Running Terraform plan for all resources..."
terraform plan \
  -var="project_id=${PROJECT_ID}" \
  -var="region=${REGION}"

if [ $? -ne 0 ]; then
  echo "Terraform plan failed. Exiting."
  exit 1
fi

read -p "Do you want to proceed with applying all Terraform changes? (yes/no): " CONFIRMATION
if [[ ! "$CONFIRMATION" =~ ^[Yy][Ee][Ss]$ ]]; then
  echo "Terraform apply cancelled by user. Exiting."
  exit 0
fi

# Apply Terraform for all resources
echo "Applying all Terraform configuration..."
terraform apply -auto-approve \
  -var="project_id=${PROJECT_ID}" \
  -var="region=${REGION}"

if [ $? -ne 0 ]; then
  echo "Terraform apply failed. Exiting."
  exit 1
fi

# Extract outputs needed for subsequent steps
echo "Extracting GCS bucket name, Pub/Sub topic name, Pub/Sub subscription name, and BigQuery dataset ID..."
GCS_BUCKET_NAME=$(terraform output -raw gcs_bucket_name)
PUBSUB_TOPIC_NAME=$(terraform output -raw pubsub_topic_name)
PUBSUB_SUBSCRIPTION_NAME=$(terraform output -raw pubsub_subscription_name)
BQ_DATASET_ID=$(terraform output -raw bigquery_dataset_id)

if [ -z "$GCS_BUCKET_NAME" ]; then
  echo "Failed to retrieve GCS bucket name from Terraform output. Exiting."
  exit 1
fi

if [ -z "$PUBSUB_TOPIC_NAME" ]; then
  echo "Failed to retrieve Pub/Sub topic name from Terraform output. Exiting."
  exit 1
fi

if [ -z "$PUBSUB_SUBSCRIPTION_NAME" ]; then
  echo "Failed to retrieve Pub/Sub subscription name from Terraform output. Exiting."
  exit 1
fi

if [ -z "$BQ_DATASET_ID" ]; then
  echo "Failed to retrieve BigQuery dataset ID from Terraform output. Exiting."
  exit 1
fi


echo "GCS Bucket Name: $GCS_BUCKET_NAME"
echo "Pub/Sub Topic Name: $PUBSUB_TOPIC_NAME"
echo "Pub/Sub Subscription Name: $PUBSUB_SUBSCRIPTION_NAME (configured for BigQuery)"
echo "BigQuery Dataset ID: $BQ_DATASET_ID"


# --- Phase 2: Replace BigQuery Native Table with Iceberg Table ---
echo ""
echo "--- Phase 2: Replacing Native BigQuery Table with Iceberg Table ---"

# Delete the existing native BigQuery table before recreating it as an Iceberg table
echo "Attempting to delete existing native BigQuery table ${BQ_DATASET_ID}.order_event_iceberg (if it exists)..."
bq rm -f -t "${PROJECT_ID}:${BQ_DATASET_ID}.order_event_iceberg" 2>/dev/null
if [ $? -ne 0 ] && [ $? -ne 1 ]; then # Check for actual errors, ignoring 'not found' (exit code 1)
  echo "Warning: Could not delete table ${BQ_DATASET_ID}.order_event_iceberg. Proceeding anyway, but check permissions if this persists."
fi


# Create a temporary SQL file for BigQuery Iceberg table creation
SQL_TEMPLATE_FILE="iceberg_table.sql"
TEMP_SQL_FILE="iceberg_table_temp.sql"

if [ ! -f "$SQL_TEMPLATE_FILE" ]; then
  echo "Error: SQL template file '$SQL_TEMPLATE_FILE' not found."
  exit 1
fi

echo "Generating temporary SQL file: $TEMP_SQL_FILE"
# Use sed to replace placeholders in the SQL file
sed "s|GCS_BUCKET_NAME_PLACEHOLDER|${GCS_BUCKET_NAME}|g; s|DATASET_ID_PLACEHOLDER|${BQ_DATASET_ID}|g; s|DATASET_REGION_PLACEHOLDER|${REGION}|g" \
    "$SQL_TEMPLATE_FILE" > "$TEMP_SQL_FILE"

# Trigger SQL for BigQuery Iceberg table creation
echo "Creating BigQuery Iceberg table 'order_event_iceberg' using bq command..."
bq query --project_id="$PROJECT_ID" --location="$REGION" --use_legacy_sql=false < "$TEMP_SQL_FILE"

if [ $? -ne 0 ]; then
  echo "BigQuery Iceberg table creation failed. Exiting."
  exit 1
fi

echo "BigQuery Iceberg table 'order_event_iceberg' created successfully."

# Clean up temporary SQL file
echo "Cleaning up temporary SQL file..."
rm "$TEMP_SQL_FILE"


echo "--- Deployment Complete ---"

echo ""
echo "Next Steps: Run your Python publisher script."
echo "Make sure you have authenticated 'gcloud' and installed necessary Python libraries:"
echo "  pip install google-cloud-pubsub faker protobuf"
echo "  python -m grpc_tools.protoc --proto_path=. --python_out=. --pyi_out=. --grpc_python_out=. order.proto"
echo ""
# MODIFIED: Instruction for running publisher.py with arguments
echo "Then run the publisher with the following command:"
echo "  python publisher.py --project_id \"$PROJECT_ID\" --topic_id \"$PUBSUB_TOPIC_NAME\""