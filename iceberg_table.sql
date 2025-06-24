-- iceberg_table.sql

-- Create the BigQuery dataset if it doesn't exist
CREATE SCHEMA IF NOT EXISTS `DATASET_ID_PLACEHOLDER`
OPTIONS(
  location = 'DATASET_REGION_PLACEHOLDER',
  description = 'Dataset for order event data, including Iceberg tables.'
);

-- Create the Iceberg table
CREATE OR REPLACE TABLE `DATASET_ID_PLACEHOLDER.order_event_iceberg` (
  order_id STRING,
  customer_id STRING,
  items ARRAY<STRUCT<
    item_id STRING,
    product_name STRING,
    quantity INT64,
    unit_price FLOAT64
  >>,
  total_amount FLOAT64,
  currency STRING,
  order_timestamp TIMESTAMP
)
WITH CONNECTION default
OPTIONS (
  file_format = 'PARQUET',
  table_format = 'ICEBERG',
  storage_uri = 'gs://GCS_BUCKET_NAME_PLACEHOLDER/iceberg/order_event'
);