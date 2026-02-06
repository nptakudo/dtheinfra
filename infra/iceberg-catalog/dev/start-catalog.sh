#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Starting Iceberg Catalog (Lakekeeper)..."

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "❌ Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if dtheinfra-network exists
if ! docker network inspect dtheinfra-network > /dev/null 2>&1; then
    echo "⚠️  Creating dtheinfra-network..."
    docker network create dtheinfra-network
fi

# Load .env if it exists
if [ -f "$SCRIPT_DIR/.env" ]; then
    echo "📋 Loading environment from .env file..."
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
else
    echo "⚠️  No .env file found. Copy .env.example to .env and configure it."
    echo "   Using default configuration..."
fi

# Start services
cd "$SCRIPT_DIR"
docker compose up -d

echo ""
echo "⏳ Waiting for Lakekeeper to be healthy..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if docker compose ps lakekeeper | grep -q "healthy"; then
        echo ""
        echo "✅ Iceberg Catalog is ready!"
        echo ""
        echo "📊 Service URLs:"
        echo "   - Iceberg REST API:  http://localhost:8181"
        echo "   - Config endpoint:   http://localhost:8181/v1/config"
        echo "   - Namespaces:        http://localhost:8181/v1/namespaces"
        echo ""
        echo "🗄️  Warehouse location: ${GCS_WAREHOUSE_URI:-gs://dtheinfra-lakehouse/warehouse/}"
        echo ""
        echo "📝 To view logs: docker compose logs -f"
        echo "🛑 To stop:      ./stop-catalog.sh"
        exit 0
    fi
    attempt=$((attempt + 1))
    sleep 2
done

echo ""
echo "⚠️  Lakekeeper is starting but not yet healthy."
echo "   Check status with: docker compose ps"
echo "   View logs with:    docker compose logs -f"
exit 1
