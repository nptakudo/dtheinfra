# DataHub - Data Catalog & Metadata Management

DataHub is a modern data catalog designed to streamline metadata management, data discovery, and data governance across your data platform.

## Features

- **Data Discovery**: Search across your entire data ecosystem
- **Data Lineage**: Track data flow and transformations
- **Data Governance**: Define ownership, PII tracking, and data quality
- **Metadata Management**: Centralized metadata store for all data assets
- **Integration**: Connect with Spark, Kafka, Airflow, dbt, and more

## Local Development Setup

### Prerequisites

- Docker Desktop installed and running
- Docker Compose V2
- Minimum resources: 2 CPUs, 8GB RAM, 12GB disk space

### Quick Start

1. **Start DataHub**:
   ```bash
   cd infra/datahub/dev
   ./start-datahub.sh
   ```

2. **Access DataHub UI**:
   - URL: http://localhost:9002
   - Username: `datahub`
   - Password: `datahub`

3. **Stop DataHub**:
   ```bash
   ./stop-datahub.sh
   ```

### Services & Ports

| Service | Port | Purpose |
|---------|------|---------|
| DataHub UI | 9002 | Web interface for data catalog |
| DataHub GMS | 8080 | Metadata service API |
| Elasticsearch | 9200 | Search indexing & graph storage |
| MySQL | 3306 | Metadata storage |
| Kafka | 9092 | Event streaming |
| Schema Registry | 8081 | Avro schema management |

### Architecture

```
┌─────────────────┐
│  DataHub UI     │  (React Frontend - Port 9002)
└────────┬────────┘
         │
┌────────▼────────┐
│  DataHub GMS    │  (Metadata Service - Port 8080)
└────────┬────────┘
         │
    ┌────┴────┐
    │         │
┌───▼──┐  ┌──▼───────────────┐
│MySQL │  │ Elasticsearch    │
│(Meta)│  │(Search + Lineage)│
└──────┘  └──────────────────┘
```

**Note**: This setup uses Elasticsearch as both the search engine and graph storage backend (instead of Neo4j) for simplicity and better resource efficiency.

## Integrating with DTHEINFRA

### 1. Airflow Integration

DataHub can ingest metadata from Airflow DAGs to track pipeline lineage.

```python
# Add to Airflow connections
datahub_rest_conn = {
    "conn_id": "datahub_rest_default",
    "conn_type": "http",
    "host": "http://datahub-gms:8086"
}
```

### 2. Spark Integration

Track Spark job lineage and dataset metadata:

```scala
// Add DataHub Spark listener to spark-defaults.conf
spark.extraListeners=datahub.spark.DatahubSparkListener
spark.datahub.rest.server=http://localhost:8086
```

### 3. Kafka Integration

Ingest Kafka topics and schema metadata:

```bash
# Install DataHub CLI (if not already installed)
pip install acryl-datahub

# Ingest Kafka metadata
datahub ingest -c kafka_recipe.yml
```

### 4. dbt Integration

Track dbt models and lineage:

```yaml
# dbt profile - add DataHub metadata
meta:
  datahub:
    enabled: true
    server: http://localhost:8086
```

## Data Ingestion

DataHub supports ingestion from 50+ data sources. Use the DataHub CLI:

```bash
# Install DataHub CLI
pip install 'acryl-datahub[datahub-rest]'

# Create ingestion recipe (example for PostgreSQL)
cat > postgres_recipe.yml <<EOF
source:
  type: postgres
  config:
    host_port: localhost:5432
    database: dataplatform
    username: dataplatform
    password: dataplatform

sink:
  type: datahub-rest
  config:
    server: http://localhost:8086
EOF

# Run ingestion
datahub ingest -c postgres_recipe.yml
```

## Useful Commands

```bash
# View all containers
docker compose ps

# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f datahub-frontend-react

# Restart a service
docker compose restart datahub-gms

# Complete cleanup (including volumes)
docker compose down -v
```

## Troubleshooting

### Services not starting
```bash
# Check container status
docker compose ps

# Check logs for errors
docker compose logs

# Verify Docker resources (needs 8GB+ RAM)
docker info | grep -i memory
```

### Frontend not accessible
```bash
# Check if GMS is healthy
curl http://localhost:8080/health

# Check frontend logs
docker compose logs datahub-frontend-react
```

### Reset everything
```bash
# Stop and remove all data
docker compose down -v

# Restart
./start-datahub.sh
```

## Resources

- [DataHub Documentation](https://docs.datahub.com/)
- [DataHub Quickstart Guide](https://docs.datahub.com/docs/quickstart)
- [DataHub Docker Deployment](https://docs.datahub.com/docs/docker)
- [DataHub GitHub](https://github.com/datahub-project/datahub)
- [Integration Guides](https://docs.datahub.com/docs/metadata-ingestion)

## Next Steps

1. Explore the UI at http://localhost:9002
2. Set up metadata ingestion from your data sources
3. Configure lineage tracking for Spark/Airflow jobs
4. Define data ownership and governance policies
5. Set up data quality rules and monitors
