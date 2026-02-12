#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Starting DataHub local environment..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Create tmp directory if it doesn't exist
mkdir -p "$SCRIPT_DIR/tmp"

# Start DataHub services
cd "$SCRIPT_DIR"
docker compose up -d

echo ""
echo "⏳ Waiting for DataHub services to be healthy..."
echo "   This may take 2-3 minutes on first startup..."

# Wait for frontend to be healthy
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker compose ps datahub-frontend-react | grep -q "healthy"; then
        echo ""
        echo "✅ DataHub is ready!"
        echo ""
        echo "📊 Access DataHub at: http://localhost:9002"
        echo "   Username: datahub"
        echo "   Password: datahub"
        echo ""
        echo "🔧 Service URLs:"
        echo "   - DataHub UI:        http://localhost:9002"
        echo "   - DataHub GMS API:   http://localhost:8086"
        echo "   - Elasticsearch:     http://localhost:9200"
        echo "   - Neo4j Browser:     http://localhost:7474 (neo4j/datahub)"
        echo "   - MySQL:             localhost:3306 (datahub/datahub)"
        echo "   - Kafka:             localhost:9092"
        echo "   - Schema Registry:   http://localhost:8085"
        echo ""
        echo "📝 To view logs: docker compose logs -f"
        echo "🛑 To stop:      ./stop-datahub.sh"
        exit 0
    fi
    attempt=$((attempt + 1))
    sleep 5
done

echo ""
echo "⚠️  DataHub services are starting but not yet healthy."
echo "   Check status with: docker compose ps"
echo "   View logs with:    docker compose logs -f"
exit 1
