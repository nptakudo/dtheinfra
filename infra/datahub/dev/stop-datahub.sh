#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🛑 Stopping DataHub local environment..."

cd "$SCRIPT_DIR"
docker compose down

echo "✅ DataHub stopped successfully!"
echo ""
echo "💡 Data is preserved in Docker volumes."
echo "   To completely remove all data, run: docker compose down -v"
