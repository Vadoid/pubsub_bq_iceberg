# publisher.py

import os
import sys
import time
import random
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


MESSAGES_PER_MINUTE = 1000
INTERVAL_SECONDS = 60 / MESSAGES_PER_MINUTE # Time to wait between each message

fake = Faker()
publisher = pubsub_v1.PublisherClient()
topic_path = publisher.topic_path(PROJECT_ID, TOPIC_ID)

print(f"Publisher initialized for topic: {topic_path}")
print(f"Publishing {MESSAGES_PER_MINUTE} messages per minute ({INTERVAL_SECONDS:.2f} seconds between messages).")

# --- START OF MODIFICATION ---
# Define a limited list of product names
PRODUCT_NAMES = [
    "Red Widget", "Blue Gadget", "Green Device", "Yellow Accessory",
    "Purple Widget", "Orange Gadget", "Black Device", "White Accessory",
    "Silver Widget", "Gold Gadget"
]
# --- END OF MODIFICATION ---


def generate_random_order():
    """Generates a random Order Protobuf message."""
    order = Order()
    order.order_id = f"ORD-{datetime.now().strftime('%Y%m%d%H%M%S')}-{random.randint(1000, 9999)}"
    order.customer_id = fake.uuid4()
    order.currency = random.choice(["USD", "EUR", "GBP", "JPY"])
    # Unix timestamp in microseconds for BQ
    order.order_timestamp = int(datetime.now().timestamp() * 1000000)

    num_items = random.randint(1, 5)
    total_amount = 0.0

    for _ in range(num_items):
        item = order.items.add()
        item.item_id = fake.isbn10()
        # --- START OF MODIFICATION ---
        # Select product name from the predefined list
        item.product_name = random.choice(PRODUCT_NAMES)
        # --- END OF MODIFICATION ---
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
        # print(f"Published message with ID: {future.result()}")
        return future.result()
    except Exception as e:
        print(f"Error publishing message: {e}")
        return None

def main():
    message_count = 0
    start_time = time.time()

    while True:
        order = generate_random_order()
        message_id = publish_message(order)

        if message_id:
            message_count += 1
            if message_count % 10 == 0: # Print a status update every 10 messages
                elapsed_time = time.time() - start_time
                print(f"Published {message_count} messages. Last message ID: {message_id}. Elapsed time: {elapsed_time:.2f}s")

        # Calculate time to wait for the next message
        time_for_next_message = start_time + (message_count * INTERVAL_SECONDS)
        sleep_duration = time_for_next_message - time.time()

        if sleep_duration > 0:
            time.sleep(sleep_duration)
        elif sleep_duration < -INTERVAL_SECONDS: # If we are too far behind, reset start_time to catch up
            print(f"Warning: Falling behind by {-sleep_duration:.2f}s. Adjusting pace.")
            start_time = time.time() - (message_count * INTERVAL_SECONDS) # Adjust start time to current actual time for pacing

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nPublisher stopped by user.")
    finally:
        publisher.transport.close()
        print("Pub/Sub publisher client closed.")