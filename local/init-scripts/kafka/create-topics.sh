#!/bin/bash
# Create default Kafka topics for the data platform

set -e

KAFKA_CONTAINER="dp-kafka"
BOOTSTRAP_SERVER="localhost:9092"

# Check if Kafka is running
if ! docker ps | grep -q $KAFKA_CONTAINER; then
    echo "Error: Kafka container is not running. Start it with 'make up-core'"
    exit 1
fi

echo "Creating Kafka topics..."

# Function to create a topic
create_topic() {
    local topic=$1
    local partitions=${2:-3}
    local replication=${3:-1}

    echo "Creating topic: $topic (partitions: $partitions, replication: $replication)"
    docker exec $KAFKA_CONTAINER kafka-topics \
        --bootstrap-server $BOOTSTRAP_SERVER \
        --create \
        --if-not-exists \
        --topic $topic \
        --partitions $partitions \
        --replication-factor $replication
}

# Raw events (high throughput)
create_topic "events.raw" 12 1

# Processed events
create_topic "events.processed" 6 1

# Dead letter queue
create_topic "events.dlq" 3 1

# CDC events
create_topic "cdc.users" 3 1
create_topic "cdc.products" 3 1
create_topic "cdc.orders" 3 1

# Aggregated metrics
create_topic "metrics.realtime" 3 1

echo ""
echo "Topics created successfully!"
echo ""
echo "Listing all topics:"
docker exec $KAFKA_CONTAINER kafka-topics \
    --bootstrap-server $BOOTSTRAP_SERVER \
    --list
