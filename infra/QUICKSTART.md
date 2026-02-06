# Iceberg + DataHub Integration - Quick Start Guide

This guide walks you through the complete setup of the Iceberg + DataHub integration POC.

## Prerequisites

- Docker Desktop with Compose V2
- GCP service account with Storage Admin role on your GCS bucket
- Service account key file downloaded
- Python 3.11+ (via `uv`)

## Step-by-Step Setup

### 1. Configure GCS Credentials

```bash
# Set your service account key path
export GCP_SA_KEY_PATH="/path/to/your/service-account-key.json"

# Or use default gcloud credentials
export GCP_SA_KEY_PATH="~/.config/gcloud/application_default_credentials.json"
```

### 2. Configure Iceberg Catalog

```bash
cd infra/iceberg-catalog/dev
cp .env.example .env

# Edit .env and set:
# - GCP_SA_KEY_PATH
# - GCS_WAREHOUSE_URI (e.g., gs://your-bucket/warehouse/)
# - GCP_PROJECT_ID
```

### 3. Start Iceberg Catalog

```bash
./start-catalog.sh
```

Wait for:
```
✅ Iceberg Catalog is ready!
📊 Service URLs:
   - Iceberg REST API:  http://localhost:8181
```

Verify it's working:
```bash
curl http://localhost:8181/v1/config
```

### 4. Start DataHub

```bash
cd infra/datahub/dev
./start-datahub.sh
```

Wait for:
```
✅ DataHub is ready!
📊 Access DataHub at: http://localhost:9002
   Username: datahub
   Password: datahub
```

### 5. Install Python Dependencies

```bash
cd /Users/takudo/Documents/dtheinfra
uv sync
```

### 6. Seed Sample Iceberg Tables

```bash
uv run python infra/datahub/dev/seed_iceberg_tables.py
```

Expected output:
```
✅ Created namespace: bronze
✅ Created namespace: silver
✅ Created namespace: gold
✅ Created table: bronze.raw_events
📝 Inserted 100 rows into bronze.raw_events
✅ Created table: silver.cleaned_events
📝 Inserted 100 rows into silver.cleaned_events
✅ Created table: gold.user_metrics
📝 Inserted 20 rows into gold.user_metrics
```

Verify tables exist:
```bash
curl http://localhost:8181/v1/namespaces
```

### 7. Run DataHub Ingestion

```bash
uv run datahub ingest -c infra/datahub/dev/recipes/iceberg_ingestion.yml
```

Expected output:
```
...
Sink (datahub-rest) report:
  Records written: 3
  Warnings: 0
  Errors: 0
```

### 8. Verify in DataHub UI

1. Open http://localhost:9002
2. Login with `datahub` / `datahub`
3. Search for: `raw_events`
4. Click on the dataset
5. Verify:
   - Schema shows all columns (user_id, event_type, timestamp, payload)
   - Properties show table format, warehouse location
   - Tags/glossary terms can be added

### 9. Test Schema Evolution

```python
# Run this script to add a column
cat > /tmp/test_schema_evolution.py <<'EOF'
from pyiceberg.catalog import load_catalog
from pyiceberg.types import NestedField, StringType

catalog = load_catalog(
    "local_lakehouse",
    **{
        "type": "rest",
        "uri": "http://localhost:8181",
        "warehouse": "gs://dtheinfra-lakehouse/warehouse/",
    }
)

table = catalog.load_table("silver.cleaned_events")
with table.update_schema() as update:
    update.add_column("source_system", StringType())

print("✅ Added column: source_system")
EOF

uv run python /tmp/test_schema_evolution.py
```

Re-run ingestion:
```bash
uv run datahub ingest -c infra/datahub/dev/recipes/iceberg_ingestion.yml
```

Verify in DataHub UI that `source_system` column now appears in the schema.

### 10. Verify End-to-End

Run the verification script:
```bash
./infra/verify-integration.sh
```

Expected:
```
✅ All services are healthy and connected!
```

## Verification Checklist

- [ ] `dtheinfra-network` Docker network exists
- [ ] Iceberg catalog responds at http://localhost:8181
- [ ] DataHub UI accessible at http://localhost:9002
- [ ] 3 namespaces created (bronze, silver, gold)
- [ ] 3 tables visible in catalog
- [ ] DataHub ingestion completes successfully
- [ ] Tables searchable in DataHub UI
- [ ] Schema matches what was created
- [ ] Schema evolution propagates after re-ingestion

## Troubleshooting

### Lakekeeper fails to start

```bash
docker compose logs lakekeeper

# Common issues:
# 1. Invalid GCS credentials
export GCP_SA_KEY_PATH="/correct/path/to/key.json"

# 2. Bucket doesn't exist - create it first
gsutil mb gs://your-bucket-name

# 3. Service account lacks permissions
# Grant "Storage Admin" role via GCP Console
```

### DataHub can't reach Iceberg catalog

```bash
# Verify both containers are on dtheinfra-network
docker network inspect dtheinfra-network

# Test connectivity from DataHub GMS
docker exec datahub-gms curl http://iceberg-catalog-lakekeeper:8181/v1/config
```

### Ingestion fails

```bash
# Run with debug logs
uv run datahub ingest -c infra/datahub/dev/recipes/iceberg_ingestion.yml --debug

# Check catalog is reachable
curl http://localhost:8181/v1/namespaces

# Verify tables exist
curl http://localhost:8181/v1/namespaces/bronze/tables
```

## Cleanup

### Stop services (keep data)
```bash
cd infra/iceberg-catalog/dev && ./stop-catalog.sh
cd infra/datahub/dev && ./stop-datahub.sh
```

### Full reset (delete all data)
```bash
cd infra/iceberg-catalog/dev && docker compose down -v
cd infra/datahub/dev && docker compose down -v

# Remove GCS data
gsutil -m rm -r gs://your-bucket/warehouse/
```

## Next Steps

1. **Add more tables**: Modify `seed_iceberg_tables.py` or create tables via Spark
2. **Set up lineage**: Configure OpenLineage to track Spark/Flink job lineage
3. **Add governance**: Define ownership, tags, glossary terms in DataHub
4. **Automate ingestion**: Set up cron job or Airflow DAG to run ingestion periodically
5. **Connect Spark**: Configure Spark to read/write Iceberg tables via the catalog
6. **Deploy to K8s**: Use the component pattern to deploy to cloud

## Reference

- Architecture: [plans/plan.md](/Users/takudo/Documents/dtheinfra/plans/plan.md)
- Component Pattern: [infra/COMPONENT_PATTERN.md](/Users/takudo/Documents/dtheinfra/infra/COMPONENT_PATTERN.md)
- Iceberg Catalog: [infra/iceberg-catalog/README.md](/Users/takudo/Documents/dtheinfra/infra/iceberg-catalog/README.md)
- DataHub: [infra/datahub/README.md](/Users/takudo/Documents/dtheinfra/infra/datahub/README.md)
