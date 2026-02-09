# Infrastructure Component Pattern

This document describes the standard pattern for creating independent, deployable infrastructure components in the dtheinfra monorepo.

## Philosophy

Each infrastructure component (DataHub, Iceberg catalog, Kafka, Spark, etc.) is an **independent brick** that:
- Can be started/stopped independently
- Has its own lifecycle and configuration
- Joins a shared network for cross-component communication
- Can be deployed locally (Docker Compose) or to cloud (K8s) using the same patterns

This enables **parallel development** where teammates can work on different components without conflicts or dependencies.

## Directory Structure

```
infra/
├── <component-name>/
│   ├── README.md                    # Component documentation
│   ├── dev/                         # Local development (Docker Compose)
│   │   ├── docker-compose.yml       # Service definitions
│   │   ├── .env.example             # Environment template
│   │   ├── start-<component>.sh     # Lifecycle: start
│   │   └── stop-<component>.sh      # Lifecycle: stop
│   └── k8s/                         # (Future) Kubernetes manifests
│       ├── deployment.yml
│       ├── service.yml
│       └── configmap.yml
```

## Docker Compose Pattern

### Networks

Every component declares two networks:

```yaml
networks:
  default:
    name: <component>_internal_network  # Internal-only communication
  dtheinfra:
    external: true
    name: dtheinfra-network             # Cross-component communication
```

- **Internal network**: Services that only need to talk within the component stay here (e.g., PostgreSQL)
- **Shared network**: Services that need to talk to other components join `dtheinfra` (e.g., REST APIs, ingestion clients)

### Service Network Attachment

Attach services to the appropriate network(s):

```yaml
services:
  # Internal-only service (e.g., database)
  postgres:
    networks:
      - default

  # Service that needs cross-component access
  api:
    networks:
      - default      # Can still talk to postgres
      - dtheinfra    # Can also talk to other components
```

### GCS/Cloud Credentials

For components that need cloud storage access:

```yaml
services:
  my-service:
    volumes:
      - ${GCP_SA_KEY_PATH:-~/.config/gcloud/application_default_credentials.json}:/secrets/gcs-key.json:ro
    environment:
      - GOOGLE_APPLICATION_CREDENTIALS=/secrets/gcs-key.json
```

Users set `GCP_SA_KEY_PATH` in `.env` (gitignored).

## Lifecycle Scripts

### `start-<component>.sh`

Standard pattern:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🚀 Starting <Component Name>..."

# Check Docker
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker not running"
    exit 1
fi

# Ensure shared network exists
if ! docker network inspect dtheinfra-network > /dev/null 2>&1; then
    echo "⚠️  Creating dtheinfra-network..."
    docker network create dtheinfra-network
fi

# Load .env if exists
if [ -f "$SCRIPT_DIR/.env" ]; then
    export $(grep -v '^#' "$SCRIPT_DIR/.env" | xargs)
fi

# Start services
cd "$SCRIPT_DIR"
docker compose up -d

# Wait for health
# ... (component-specific health checks)

echo "✅ <Component> is ready!"
```

### `stop-<component>.sh`

Standard pattern:

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🛑 Stopping <Component>..."

cd "$SCRIPT_DIR"
docker compose down

echo "✅ <Component> stopped"
echo "💡 To remove volumes: docker compose down -v"
```

## README.md Template

Each component's README should include:

1. **Overview** - What the component does, key features
2. **Architecture** - Diagram showing services and connections
3. **Prerequisites** - What's needed before starting (credentials, other components)
4. **Quick Start** - Copy .env.example, configure, start
5. **Integration** - How other components connect to this one
6. **Usage Examples** - Code snippets showing typical usage
7. **Services & Ports** - Table of exposed services
8. **Troubleshooting** - Common issues and solutions
9. **Resources** - External documentation links

## .env.example Template

```bash
# Component-specific configuration
COMPONENT_PORT=8080

# GCS/Cloud credentials (if needed)
GCP_SA_KEY_PATH=~/.config/gcloud/application_default_credentials.json
GCS_BUCKET_URI=gs://your-bucket/path/

# Optional: Logging, debugging
LOG_LEVEL=info
DEBUG=false
```

## Example: Creating a New Component

Let's say you want to add Apache Kafka as a component:

```bash
# 1. Create directory structure
mkdir -p infra/kafka/dev

# 2. Create docker-compose.yml
cat > infra/kafka/dev/docker-compose.yml <<EOF
networks:
  default:
    name: kafka_internal_network
  dtheinfra:
    external: true
    name: dtheinfra-network

services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.5.3
    networks:
      - default
    # ... config

  kafka:
    image: confluentinc/cp-kafka:7.5.3
    networks:
      - default
      - dtheinfra  # Exposed to other components
    ports:
      - "9092:9092"
    # ... config
EOF

# 3. Create .env.example
cat > infra/kafka/dev/.env.example <<EOF
KAFKA_PORT=9092
KAFKA_TOPICS=events.raw,events.processed
EOF

# 4. Create lifecycle scripts
cat > infra/kafka/dev/start-kafka.sh <<'EOF'
#!/bin/bash
# ... (follow pattern above)
EOF
chmod +x infra/kafka/dev/start-kafka.sh

cat > infra/kafka/dev/stop-kafka.sh <<'EOF'
#!/bin/bash
# ... (follow pattern above)
EOF
chmod +x infra/kafka/dev/stop-kafka.sh

# 5. Write README.md
cat > infra/kafka/README.md <<EOF
# Apache Kafka

Message streaming platform for event-driven architecture.

## Quick Start
...
EOF
```

## Cross-Component Communication

### Connecting to Other Components

From any component on `dtheinfra-network`, you can reach other components by container name:

```python
# Python example: Connect to Iceberg catalog from a script
catalog_uri = "http://iceberg-catalog-lakekeeper:8181"

# Connect to DataHub GMS
datahub_gms = "http://datahub-gms:8080"

# Connect to Kafka
kafka_brokers = "kafka:9092"
```

### Service Discovery

Container names follow the pattern: `<component>-<service-name>`

Examples:
- `iceberg-catalog-lakekeeper` - Lakekeeper REST API
- `datahub-gms` - DataHub metadata service
- `kafka` - Kafka broker

## K8s Deployment (Future)

The same component pattern translates to Kubernetes:

- `docker-compose.yml` → `deployment.yml` + `service.yml`
- `.env` → `ConfigMap` + `Secret`
- `dtheinfra-network` → Service mesh or namespace-scoped DNS
- Lifecycle scripts → `kubectl apply -f infra/<component>/k8s/`

## Benefits

1. **Independent Development**: Teams work on components without blocking each other
2. **Selective Startup**: Only start what you need for your work
3. **Consistent UX**: All components follow same patterns (start script, .env, README)
4. **Easy Testing**: Test component in isolation, then integration
5. **Cloud-Ready**: Local dev mimics cloud deployment structure

## Examples in This Repo

- `infra/datahub/` - Full DataHub stack with internal Kafka/MySQL + external GMS
- `infra/iceberg-catalog/` - Lakekeeper + Postgres with GCS integration
- `infra/coder/` - Development environments (simpler, single-service example)
