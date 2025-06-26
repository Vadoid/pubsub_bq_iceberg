# publisher.py

import os
import sys
import time
import random
import string
from datetime import datetime, timedelta

from google.cloud import pubsub_v1
from google.protobuf import json_format
from faker import Faker

# Import the generated protobuf code
from order_pb2 import Order # Only import the top-level message


def parse_arguments():
    project_id = None
    topic_id = None
    args = sys.argv[1:]

    i = 0
    while i < len(args):
        if args[i] == "--project_id":
            if i + 1 < len(args):
                project_id = args[i+1]
                i += 1
            else:
                print("Error: --project_id requires a value.")
                sys.exit(1)
        elif args[i] == "--topic_id":
            if i + 1 < len(args):
                topic_id = args[i+1]
                i += 1
            else:
                print("Error: --topic_id requires a value.")
                sys.exit(1)
        i += 1

    if not project_id or not topic_id:
        print("Usage: python publisher.py --project_id <YOUR_GCP_PROJECT_ID> --topic_id <YOUR_PUBSUB_TOPIC_ID>")
        sys.exit(1)
    return project_id, topic_id

PROJECT_ID, TOPIC_ID = parse_arguments()


MESSAGES_PER_MINUTE = 10000
INTERVAL_SECONDS = 60 / MESSAGES_PER_MINUTE

fake = Faker()
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)

print(f"Publisher initialized for topic: {topic_path}")
print(f"Publishing {MESSAGES_PER_MINUTE} messages per minute ({INTERVAL_SECONDS:.4f} seconds between messages).")

# Helper function to generate a random alphanumeric ID for initial product setup
def generate_alphanumeric_id(length=8):
    characters = string.ascii_uppercase + string.digits
    return ''.join(random.choice(characters) for i in range(length))

# Define a list of fixed products, where each product is a dictionary
# containing a unique item_id and its corresponding product_name.
FIXED_PRODUCTS = [
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Red Widget"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Blue Gadget"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Green Device"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Yellow Accessory"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Purple Widget"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Orange Gadget"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Black Device"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "White Accessory"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Silver Widget"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Gold Gadget"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Bronze Ornament"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Copper Trinket"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Diamond Tool"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Emerald Holder"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Ruby Lamp"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Sapphire Bell"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Titanium Spoon"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Platinum Fork"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Iron Knife"},
    {"item_id": f"PROD-{generate_alphanumeric_id()}", "product_name": "Steel Plate"}
]

# --- START OF MODIFICATION ---
# Create a pool of 15 unique customer IDs
CUSTOMER_ID_POOL = [fake.uuid4() for _ in range(15)]
print(f"Generated a pool of {len(CUSTOMER_ID_POOL)} customer IDs.")
# --- END OF MODIFICATION ---

# Calculate the time range for timestamps
END_DATE = datetime.now()
START_DATE = END_DATE - timedelta(days=90) # Three months ago (approx. 90 days)
TIME_RANGE_SECONDS = (END_DATE - START_DATE).total_seconds()

def get_random_timestamp_in_range():
    """Generates a random datetime object within the defined range."""
    random_second = random.uniform(0, TIME_RANGE_SECONDS)
    return START_DATE + timedelta(seconds=random_second)


def generate_random_order():
    """Generates a random Order Protobuf message."""
    order = Order()
    order.order_id = f"ORD-{datetime.now().strftime('%Y%m%d%H%M%S')}-{random.randint(1000, 9999)}"
    # --- START OF MODIFICATION ---
    # Select a customer ID from the predefined pool
    order.customer_id = random.choice(CUSTOMER_ID_POOL)
    # --- END OF MODIFICATION ---
    order.currency = random.choice(["USD", "EUR", "GBP", "JPY"])
    order.order_timestamp = int(get_random_timestamp_in_range().timestamp() * 1000000)

    num_items = random.randint(1, 5)
    total_amount = 0.0

    for _ in range(num_items):
        item = order.items.add()
        chosen_product = random.choice(FIXED_PRODUCTS)
        item.item_id = chosen_product["item_id"]
        item.product_name = chosen_product["product_name"]
        item.quantity = random.randint(1, 10)
        item.unit_price = round(random.uniform(5.0, 500.0), 2)
        total_amount += item.quantity * item.unit_price

    order.total_amount = round(total_amount, 2)
    return order

def publish_message(order_message):
    """Publishes a single Protobuf message to Pub/Sub."""
    try:
        data = json_format.MessageToJson(order_message).encode("utf-8")
        future = publisher.publish(topic_path, data, encoding='json')
        return future.result()
    except Exception as e:
        print(f"Error publishing message: {e}")
        return None

def main():
    message_count = 0
    start_time = time.time()

    print("Starting message publication...")

    while True:
        order = generate_random_order()
        message_id = publish_message(order)

        if message_id:
            message_count += 1
            if message_count % 1000 == 0:
                elapsed_time = time.time() - start_time
                print(f"Published {message_count} messages. Last message ID: {message_id}. Elapsed time: {elapsed_time:.2f}s")

        time_for_next_message = start_time + (message_count * INTERVAL_SECONDS)
        sleep_duration = time_for_next_message - time.time()

        if sleep_duration > 0:
            time.sleep(sleep_duration)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nPublisher stopped by user.")
    finally:
        publisher.transport.close()
        print("Pub/Sub publisher client closed.")