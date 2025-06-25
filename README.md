# Real-time Order Processing: Pub/Sub, BigQuery Iceberg via Terraform

This quick demo demonstrates a real-time data pipeline for order event ingestion and analytics. It leverages Pub/Sub for messaging, BigQuery for warehousing, and Apache Iceberg tables for BigQuery. 
Infrastructure is managed entirely by Terraform, orchestrated via a bash script.

## Overview

Ingest simulated real-time order events via Pub/Sub into BigQuery Iceberg table.

Step by step explanation of what the script + Terraform does:
1. Creates Pub/Sub topic in format `order-events-${random_id.topic_suffix.hex}`
2. Creates GCS bucket in format `${var.project_id}-${random_id.bucket_suffix.hex}` - this will be used to store Iceberg data.
3. Creates dataset `orders` and table `order_event_iceberg` as native table.
4. Creates push to BigQUery subscription from Pub/Sub topic to `order_event_iceberg`.
5. Replaces native `order_event_iceberg` with BigQuery Table for Apache Iceberg.
6. Last step script will output `publisher.py` with correct parameters. That script will start sending messages to Pub/Sub topic which would be immidiately visible in Iceberg table's streaming buffer.
7. Streaming buffer will merge in a bout 60 minutes (or less) and the last step would be to run SQL query `EXPORT TABLE METADATA FROM orders.order_event_iceberg` - this way all the metadata files will be exported to GCS storage location.


## Getting Started

### Prerequisites

* GCP Project with `Editor` role (or equivalent IAM)
* Google Cloud SDK (`gcloud`, `bq` CLI configured)
* Terraform (duh)
* Install dependencies via `pip install google-cloud-pubsub faker protobuf` (in GCP console all should be available, except faker)
* `protoc` compiler - `pip install grpcio-tools` <-this will take awhile (to generate `order_pb2.py`) (optional, if you decide to change the schema just because I've had lot's of time on my hands (no, I'm just lazy) and wanted to use protobuf. By the way, if you are curious, this solution will also work with BINARY protobuf messages encoding (as opposed to JSON) pretty cool, eh?)

### Deployment Steps

1. **Clone this repo, don't change anything.**

2.  **Generate Python Protobuf code - OPTIONAL, ONLY IF YOU DECIDE TO CHANGE PROTO SCHEMA**:
     ```bash
    python -m grpc_tools.protoc --proto_path=. --python_out=. order.proto
    ```
2.  **Run deployment script**: The script will handle Terraform apply (creating base infra, BQ dataset & placeholder table, Pub/Sub topic & BQ subscription), followed by SQL execution to transform the BQ table to Iceberg.
    ```bash
    chmod +x deploy.sh
    ./deploy.sh --project_id your-gcp-project-id --region us-central1
    ```
3. **Confirm `Do you want to proceed with applying all Terraform changes? (yes/no)` message checking that the plan and the resources to be created are in line with expectations (they should be).** 

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
