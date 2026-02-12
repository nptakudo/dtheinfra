# Iceberg Catalog (Lakekeeper)

Apache Iceberg REST catalog powered by Lakekeeper - a lightweight, Rust-based catalog with native GCS support.

## Features

- **Iceberg REST API**: Standard REST catalog interface compatible with all Iceberg engines
- **GCS Native**: Direct integration with Google Cloud Storage (no S3 emulation)
- **Lightweight**: Rust-based, minimal resource footprint, fast startup
- **Transactional**: PostgreSQL backend for ACID catalog operations
- **Multi-engine**: Works with Spark, Flink, Trino, PyIceberg, and any Iceberg-compatible engine

## Architecture

```
┌─────────────────────┐
│   GCS Bucket        │
│   warehouse/        │
│   ├── bronze/       │
│   ├── silver/       │
│   └── gold/         │
└──────────▲──────────┘
           │
┌──────────┴──────────┐
│  Lakekeeper :8181   │  (Iceberg REST API)
│  + Postgres         │  (Catalog metadata)
└─────────────────────┘
```

## Prerequisites

- Docker Desktop with Compose V2
- GCP service account with Storage Admin permissions on your GCS bucket
- Service account key file downloaded locally

## Quick Start

### 1. Configure

Copy the example environment file:
```bash
cd infra/iceberg-catalog/dev
cp .env.example .env
```

Edit `.env` and set:
```bash
GCP_SA_KEY_PATH=/path/to/your/service-account-key.json
GCS_WAREHOUSE_URI=gs://your-bucket-name/warehouse/
GCP_PROJECT_ID=your-gcp-project
```

### 2. Start Catalog

```bash
./start-catalog.sh
```

The catalog will be available at: **http://localhost:8181**

### 3. Verify

```bash
# Check catalog config
curl http://localhost:8181/v1/config

# List namespaces
curl http://localhost:8181/v1/namespaces

# Check health
docker compose ps
```

### 4. Stop Catalog

```bash
./stop-catalog.sh
```

## Integration with Other Components

This catalog joins the **`dtheinfra-network`** Docker network, making it accessible to other infra components:

- **DataHub** can ingest metadata via the Iceberg source connector
- **Spark** can read/write tables via the REST catalog interface
- **PyIceberg** scripts can manage tables programmatically

## Usage Examples

### PyIceberg

```python
from pyiceberg.catalog import load_catalog

catalog = load_catalog(
    "local_lakehouse",
    **{
        "type": "rest",
        "uri": "http://localhost:8181",
        "warehouse": "gs://your-bucket/warehouse/",
    }
)

# List namespaces
namespaces = catalog.list_namespaces()

# Create namespace
catalog.create_namespace("bronze")

# Create table
from pyiceberg.schema import Schema
from pyiceberg.types import NestedField, StringType, TimestampType

schema = Schema(
    NestedField(1, "user_id", StringType(), required=True),
    NestedField(2, "event_type", StringType(), required=True),
    NestedField(3, "timestamp", TimestampType(), required=True),
)

table = catalog.create_table(
    "bronze.raw_events",
    schema=schema,
)
```

### Spark (via spark-defaults.conf)

```properties
spark.sql.catalog.lakehouse=org.apache.iceberg.spark.SparkCatalog
spark.sql.catalog.lakehouse.type=rest
spark.sql.catalog.lakehouse.uri=http://lakekeeper:8181
spark.sql.catalog.lakehouse.warehouse=gs://your-bucket/warehouse/
spark.sql.catalog.lakehouse.gcs.project-id=your-gcp-project
```

## Services & Ports

| Service | Port | Purpose |
|---------|------|---------|
| Lakekeeper | 8181 | Iceberg REST API |
| PostgreSQL | (internal) | Catalog metadata storage |

## Troubleshooting

### Lakekeeper not starting

```bash
# Check logs
docker compose logs -f lakekeeper

# Common issues:
# 1. GCS credentials invalid - verify GCP_SA_KEY_PATH
# 2. Bucket doesn't exist - create it first via GCP console
# 3. Service account lacks permissions - needs Storage Admin role
```

### Connection errors from other components

```bash
# Verify network connectivity
docker network inspect dtheinfra-network

# Ensure Lakekeeper is in the network
docker inspect iceberg-catalog-lakekeeper | grep -A5 Networks
```

### Reset everything

```bash
# Stop and remove all data
docker compose down -v

# Restart
./start-catalog.sh
```

## Component Pattern

This follows the infra component pattern for dtheinfra:

- **Independent deployment**: Starts/stops without affecting other components
- **Shared network**: Joins `dtheinfra-network` for cross-component communication
- **Standardized scripts**: `start-catalog.sh` and `stop-catalog.sh` for lifecycle management
- **Environment-based config**: `.env` file for local customization (gitignored)

Teammates can replicate this pattern for other infra bricks (Kafka, Spark, etc.).

## Resources

- [Lakekeeper Documentation](https://docs.lakekeeper.io/)
- [Lakekeeper GitHub](https://github.com/lakekeeper/lakekeeper)
- [Apache Iceberg REST Catalog Spec](https://iceberg.apache.org/rest-catalog-spec/)
- [PyIceberg Documentation](https://py.iceberg.apache.org/)

## Next Steps

1. Create sample tables with `seed_iceberg_tables.py`
2. Integrate with DataHub for metadata catalog
3. Connect Spark/Flink engines for data processing
4. Set up lineage tracking via OpenLineage
