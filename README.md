# Real-time Order Processing: Pub/Sub, BigQuery Iceberg via Terraform

This quick demo demonstrates a real-time data pipeline for order event ingestion and analytics. It leverages Pub/Sub for messaging, BigQuery for warehousing, and Apache Iceberg tables for BigQuery. 
Infrastructure is managed entirely by Terraform, orchestrated via a bash script.

## Overview

Ingest simulated real-time order events, validate them with Protobuf schemas on Pub/Sub, and store them in BigQuery Apache Iceberg Tables, queryable via BigQuery and Serverless spark.

## Key Technologies

* **GCP**: Pub/Sub, BigQuery, Cloud Storage (GCS)
* **IaC**: Terraform
* **Data Format**: Apache Iceberg
* **Schema**: Protobuf
* **Publisher**: Python

## Features

* Automated GCP Infrastructure (IaC)
* Real-time Messaging with Schema Validation
* Open Data Lake Table Format (Iceberg on GCS)
* Direct BigQuery Integration
* Streamlined Deployment Script

## Getting Started

### Prerequisites

* GCP Project with `Editor` role (or equivalent IAM)
* Google Cloud SDK (`gcloud`, `bq` CLI configured)
* Terraform `~> 1.0`
* Python 3 + `pip` (`google-cloud-pubsub`, `faker`, `protobuf`)
* `protoc` compiler (to generate `order_pb2.py`) (optional, if you decicde to change the schema)

### Deployment Steps

1.  **Generate Python Protobuf code - OPTIONAL, ONLY IF YOU CHANGE PROTO SCHEMA**:
    ```bash
    python -m grpc_tools.protoc --proto_path=. --python_out=. --pyi_out=. --grpc_python_out=. order.proto
    ```
2.  **Run deployment script**: The script will handle Terraform apply (creating base infra, BQ dataset & placeholder table, Pub/Sub topic & BQ subscription), followed by SQL execution to transform the BQ table to Iceberg.
    ```bash
    chmod +x deploy.sh
    ./deploy.sh --project_id your-gcp-project-id --region us-central1
    ```

### Running the Publisher

The deployment script will output the exact command. Example:

```bash
python publisher.py --project_id "your-gcp-project-id" --topic_id "order-events-<random_suffix>"
```

## Cleanup

Run 
```bash
terraform destroy
```
