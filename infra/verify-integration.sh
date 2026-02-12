#!/bin/bash
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  Iceberg + DataHub Integration Verification${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Function to check if a service is healthy
check_service() {
    local service_name=$1
    local url=$2
    local description=$3

    echo -n "Checking $description... "
    if curl -sf "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

# Function to check Docker network
check_network() {
    echo -n "Checking dtheinfra-network exists... "
    if docker network inspect dtheinfra-network > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        echo -e "${YELLOW}  Run: docker network create dtheinfra-network${NC}"
        return 1
    fi
}

# Function to check if a container is on the network
check_container_network() {
    local container=$1
    echo -n "Checking $container is on dtheinfra-network... "
    if docker inspect "$container" 2>/dev/null | grep -q "dtheinfra-network"; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        return 1
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1️⃣  Network Setup"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_network
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2️⃣  Iceberg Catalog Service"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_service "Lakekeeper" "http://localhost:8181/v1/config" "Iceberg REST API"

if [ $? -eq 0 ]; then
    check_container_network "iceberg-catalog-lakekeeper"

    echo -n "Checking for Iceberg namespaces... "
    NAMESPACES=$(curl -sf http://localhost:8181/v1/namespaces 2>/dev/null | jq -r '.namespaces[][]' 2>/dev/null | wc -l)
    if [ "$NAMESPACES" -gt 0 ]; then
        echo -e "${GREEN}✓ ($NAMESPACES found)${NC}"
        curl -sf http://localhost:8181/v1/namespaces | jq -r '.namespaces[][]' | sed 's/^/    /'
    else
        echo -e "${YELLOW}⚠ No namespaces found${NC}"
        echo -e "${YELLOW}  Run: uv run python infra/datahub/dev/seed_iceberg_tables.py${NC}"
    fi
else
    echo -e "${YELLOW}  Start catalog: cd infra/iceberg-catalog/dev && ./start-catalog.sh${NC}"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3️⃣  DataHub Services"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
check_service "DataHub GMS" "http://localhost:8080/health" "Metadata Service"
check_service "DataHub UI" "http://localhost:9002" "Web Interface"

if docker inspect datahub-gms > /dev/null 2>&1; then
    check_container_network "datahub-gms"
else
    echo -e "${YELLOW}  Start DataHub: cd infra/datahub/dev && ./start-datahub.sh${NC}"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4️⃣  End-to-End Connectivity"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if docker inspect datahub-gms > /dev/null 2>&1 && docker inspect iceberg-catalog-lakekeeper > /dev/null 2>&1; then
    echo -n "Testing DataHub → Iceberg catalog connectivity... "

    # Test if DataHub GMS can reach the catalog
    if docker exec datahub-gms curl -sf http://iceberg-catalog-lakekeeper:8181/v1/config > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗${NC}"
        echo -e "${YELLOW}  Both containers must be on dtheinfra-network${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Both services must be running for connectivity test${NC}"
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "5️⃣  Summary & Next Steps"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

ALL_GOOD=true

if ! docker network inspect dtheinfra-network > /dev/null 2>&1; then
    ALL_GOOD=false
fi

if ! curl -sf http://localhost:8181/v1/config > /dev/null 2>&1; then
    ALL_GOOD=false
fi

if ! curl -sf http://localhost:8080/health > /dev/null 2>&1; then
    ALL_GOOD=false
fi

if [ "$ALL_GOOD" = true ]; then
    echo -e "${GREEN}✅ All services are healthy and connected!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Seed tables (if not done):"
    echo "     uv run python infra/datahub/dev/seed_iceberg_tables.py"
    echo ""
    echo "  2. Run DataHub ingestion:"
    echo "     uv run datahub ingest -c infra/datahub/dev/recipes/iceberg_ingestion.yml"
    echo ""
    echo "  3. Check DataHub UI:"
    echo "     open http://localhost:9002"
    echo "     Search for: raw_events, cleaned_events, user_metrics"
else
    echo -e "${YELLOW}⚠ Some services are not ready. Fix the issues above first.${NC}"
    echo ""
    echo "Quick start commands:"
    echo "  1. Create network:"
    echo "     docker network create dtheinfra-network"
    echo ""
    echo "  2. Start Iceberg catalog:"
    echo "     cd infra/iceberg-catalog/dev && ./start-catalog.sh"
    echo ""
    echo "  3. Start DataHub:"
    echo "     cd infra/datahub/dev && ./start-datahub.sh"
    echo ""
    echo "  4. Run this script again to verify"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
