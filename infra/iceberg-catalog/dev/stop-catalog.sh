#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🛑 Stopping Iceberg Catalog..."

cd "$SCRIPT_DIR"
docker compose down

echo "✅ Iceberg Catalog stopped."
echo ""
echo "💡 To remove all data volumes, run: docker compose down -v"
