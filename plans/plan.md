# POC: Iceberg + DataHub Integration

## Context

We need to prove that Apache Iceberg tables (stored on GCS) can be managed through an Iceberg catalog and their metadata surfaced in DataHub. This is the foundation layer — the AI agent stuff comes later.

**Current state:**
- DataHub stack exists at `infra/datahub/dev/` (self-contained, own `datahub_network`)
- Most other `infra/` components are placeholder READMEs only
- `local/` folder exists but is NOT part of this work (monorepo pattern: each component deploys independently)
- Storage: **GCS directly** (real Google Cloud Storage, no emulator, both local dev and cloud)

**Problem:** No Iceberg catalog component exists yet, and DataHub has no metadata integration with Iceberg.

**Goal:**
1. Stand up an Iceberg catalog as an independent brick under `infra/`
2. Connect DataHub to ingest Iceberg table metadata
3. Establish a component pattern that teammates can replicate for other infra bricks

---

## Iceberg Catalog Options (GCS-focused)

Since we're using real GCS, the catalog must support `GCSFileIO` natively. Note: the `tabulario/iceberg-rest` image in the existing `local/docker-compose.yml` is deprecated — it's been replaced by `apache/iceberg-rest-fixture` (official Apache image). Both are test fixtures, not production catalogs, and neither ships with GCS jars by default.

### Option A: Lakekeeper — Recommended for this POC

Lightweight Rust-based Iceberg REST catalog. Native GCS support via service account key.

| Aspect | Detail |
|--------|--------|
| **GCS support** | Native — service-account-key or system identity auth |
| **Pros** | Lightweight (Rust, no JVM), fast startup, full Iceberg REST API, built-in UI, K8s-ready, OAuth2/OIDC support |
| **Cons** | Youngest project, smaller community |
| **Docker image** | `quay.io/lakekeeper/catalog` |
| **Backend DB** | PostgreSQL (or SQLite for dev) |
| **DataHub compat** | Yes — standard Iceberg REST API, DataHub's `iceberg` source works against it |
| **Best for** | POC, lightweight deployments, GCS-native |

### Option B: Project Nessie

Git-style transactional catalog. GCS support via `GCSFileIO` configuration.

| Aspect | Detail |
|--------|--------|
| **GCS support** | Supported — configure `gcs.project-id` + credentials |
| **Pros** | Git-like branching/tagging, multi-table atomic commits, Iceberg REST API compatible, mature community, Helm chart available |
| **Cons** | JVM-based (heavier), learning curve for git-style data ops |
| **Docker image** | `ghcr.io/projectnessie/nessie` |
| **Backend DB** | JDBC (Postgres), RocksDB, DynamoDB, Cassandra |
| **DataHub compat** | Yes — exposes Iceberg REST API |
| **Best for** | Teams wanting data versioning, branching experiments |

### Option C: Apache Polaris (incubating)

Enterprise-grade REST catalog with fine-grained RBAC.

| Aspect | Detail |
|--------|--------|
| **GCS support** | Supported — credential vending, GCSFileIO |
| **Pros** | RBAC at catalog/namespace/table level, credential vending, federation from other catalogs, ASF project |
| **Cons** | Heaviest setup, more config, incubating status |
| **Docker image** | Build from source or use community images |
| **Backend DB** | PostgreSQL |
| **DataHub compat** | Yes — implements Iceberg REST spec |
| **Best for** | Multi-tenant governance, production RBAC |

### Recommendation

**Option A (Lakekeeper)** for this POC because:
- Native GCS support with zero custom image builds
- Lightest resource footprint (Rust, no JVM overhead)
- Fastest to get running
- Same Iceberg REST API as everything else, so switching to Nessie/Polaris later is a config change, not a rewrite

The catalog choice is **orthogonal to the DataHub integration** — DataHub's `iceberg` ingestion source works with any catalog exposing the REST API. Swapping catalogs later doesn't affect the DataHub side.

---

## Architecture

```
infra/
├── datahub/                  # Brick 1 (exists)
│   └── dev/
│       ├── docker-compose.yml
│       ├── recipes/
│       │   └── iceberg_ingestion.yml   ← NEW
│       ├── seed_iceberg_tables.py      ← NEW
│       ├── start-datahub.sh
│       └── stop-datahub.sh
│
├── iceberg-catalog/          # Brick 2 (NEW)
│   ├── README.md
│   └── dev/
│       ├── docker-compose.yml          ← Lakekeeper + Postgres
│       ├── .env.example
│       ├── start-catalog.sh
│       └── stop-catalog.sh
│
└── ... (future bricks by teammates)
```

### Component Connectivity

```
         ┌─────────────────────────┐
         │       GCS Bucket        │
         │  gs://your-bucket/      │
         │  └── warehouse/         │
         │      ├── bronze/        │
         │      ├── silver/        │
         │      └── gold/          │
         └────────────▲────────────┘
                      │ (reads/writes data files)
                      │
┌─────────────────────┼─────────────────────────┐
│   Shared Docker Network: dtheinfra-network     │
│                     │                          │
│  ┌──────────────────┴──────────┐               │
│  │  Iceberg Catalog            │               │
│  │  (Lakekeeper :8181)         │               │
│  │  + Postgres (catalog meta)  │               │
│  └──────────────▲──────────────┘               │
│                 │                               │
│        ┌───────┴────────┐                      │
│        │                │                      │
│  ┌─────┴──────┐  ┌─────┴──────────┐           │
│  │  PyIceberg │  │  DataHub GMS   │           │
│  │  (seed     │  │  (ingestion    │           │
│  │   tables)  │  │   source)      │           │
│  └────────────┘  └─────┬──────────┘           │
│                        │                       │
│                  ┌─────▼──────────┐            │
│                  │  DataHub UI    │            │
│                  │  :9002         │            │
│                  └────────────────┘            │
└────────────────────────────────────────────────┘
```

### Shared Network Convention

All infra bricks join the same external Docker network: **`dtheinfra-network`**. Each component declares it as external and attaches the services that need cross-component communication. Components that don't need to talk to others can remain internal-only.

```yaml
# Convention for every infra component's docker-compose.yml:
networks:
  default:
    name: component_internal_network
  dtheinfra:
    external: true
    name: dtheinfra-network
```

The network is created once (manually or via a script):
```bash
docker network create dtheinfra-network
```

### GCS Credentials

All components that need GCS access mount a service account key file:

```yaml
volumes:
  - ${GCP_SA_KEY_PATH:-~/.config/gcloud/application_default_credentials.json}:/secrets/gcs-key.json:ro
environment:
  - GOOGLE_APPLICATION_CREDENTIALS=/secrets/gcs-key.json
```

Teammates set `GCP_SA_KEY_PATH` in their local `.env` file (gitignored). For K8s deployment, this becomes a Secret mount.

---

## POC Scope

### In Scope
1. Create `infra/iceberg-catalog/` as an independent deployable brick (Lakekeeper + Postgres)
2. Configure it to use GCS as the warehouse storage
3. Seed sample Iceberg tables (bronze/silver/gold) via PyIceberg
4. Create DataHub ingestion recipe for the Iceberg source
5. Run ingestion and verify metadata appears in DataHub UI
6. Test schema evolution propagation
7. Establish the shared network convention for the monorepo

### Out of Scope
- AI agent layer (deferred)
- Cloud K8s deployment (pattern is set, actual deploy is later)
- Lineage tracking (OpenLineage)
- DataHub-as-Iceberg-catalog mode (beta)
- Other infra bricks (Kafka, Spark, etc.)

### Success Criteria

| # | Criterion | Verification |
|---|-----------|--------------|
| 1 | Iceberg catalog starts independently | `./start-catalog.sh` → Lakekeeper healthy at `:8181` |
| 2 | Tables created on GCS via PyIceberg | `curl :8181/v1/namespaces` lists bronze/silver/gold |
| 3 | Data files exist in GCS | `gsutil ls gs://bucket/warehouse/` shows parquet files |
| 4 | DataHub ingestion succeeds | `datahub ingest` exits 0 |
| 5 | Tables visible in DataHub UI | Search finds tables, schemas match |
| 6 | Schema evolution propagates | Add column → re-ingest → DataHub shows new column |
| 7 | Both bricks start/stop independently | Stop catalog, DataHub still runs (and vice versa) |

---

## Implementation Steps

### Step 1: Create Shared Network Convention

Create a simple script or Makefile target to ensure the shared Docker network exists:
```bash
docker network create dtheinfra-network 2>/dev/null || true
```

### Step 2: Create `infra/iceberg-catalog/` Brick

New directory with:
- `dev/docker-compose.yml` — Lakekeeper container + Postgres for catalog metadata
- `dev/.env.example` — GCS bucket, project ID, service account key path
- `dev/start-catalog.sh` / `dev/stop-catalog.sh` — lifecycle scripts
- `README.md` — setup instructions, architecture notes

The Lakekeeper service:
- Listens on `:8181` (Iceberg REST API)
- Connects to GCS via service account credentials
- Warehouse: `gs://<bucket>/warehouse/`
- Joins `dtheinfra-network` for cross-component access

### Step 3: Update DataHub Brick to Join Shared Network

Modify `infra/datahub/dev/docker-compose.yml`:
- Add `dtheinfra-network` as external network
- Attach `datahub-gms` to it (so ingestion can reach the catalog)
- Keep `datahub_network` for internal DataHub communication

### Step 4: Seed Sample Iceberg Tables

Create `infra/datahub/dev/seed_iceberg_tables.py` using PyIceberg + gcsfs:

Tables:
- `bronze.raw_events` — user_id, event_type, timestamp, payload
- `silver.cleaned_events` — user_id, event_type, event_time, processed_at
- `gold.user_metrics` — user_id, event_count, last_event_time

~100 rows each. Uses PyIceberg REST catalog client pointed at `localhost:8181`.

Add dependencies to `pyproject.toml`:
```toml
dependencies = [
    "acryl-datahub>=1.3.1.10",
    "pyiceberg[gcsfs,pyarrow]>=0.8.1",
]
```

### Step 5: Create DataHub Ingestion Recipe

Create `infra/datahub/dev/recipes/iceberg_ingestion.yml`:

```yaml
source:
  type: iceberg
  config:
    catalog:
      local_lakehouse:
        type: rest
        uri: http://localhost:8181
        warehouse: gs://<bucket>/warehouse/
    platform_instance: local_lakehouse

sink:
  type: datahub-rest
  config:
    server: http://localhost:8080
```

### Step 6: Verify End-to-End

1. Create network: `docker network create dtheinfra-network`
2. Start Iceberg catalog: `cd infra/iceberg-catalog/dev && ./start-catalog.sh`
3. Start DataHub: `cd infra/datahub/dev && ./start-datahub.sh`
4. Seed tables: `uv run python infra/datahub/dev/seed_iceberg_tables.py`
5. Run ingestion: `uv run datahub ingest -c infra/datahub/dev/recipes/iceberg_ingestion.yml`
6. Open http://localhost:9002 → search "raw_events" → verify schema
7. Schema evolution test: add column via PyIceberg → re-ingest → check DataHub

### Step 7: Document

- `infra/iceberg-catalog/README.md` — catalog setup, GCS config, architecture
- Update `infra/datahub/README.md` — add Iceberg integration section
- Add component pattern notes so teammates can replicate for Kafka, Spark, etc.

---

## Key Files

| File | Action | Purpose |
|------|--------|---------|
| `infra/iceberg-catalog/dev/docker-compose.yml` | **Create** | Lakekeeper + Postgres stack |
| `infra/iceberg-catalog/dev/.env.example` | **Create** | GCS credentials template |
| `infra/iceberg-catalog/dev/start-catalog.sh` | **Create** | Lifecycle script |
| `infra/iceberg-catalog/dev/stop-catalog.sh` | **Create** | Lifecycle script |
| `infra/iceberg-catalog/README.md` | **Create** | Component documentation |
| `infra/datahub/dev/docker-compose.yml` | **Modify** | Add `dtheinfra-network` |
| `infra/datahub/dev/seed_iceberg_tables.py` | **Create** | PyIceberg table seeder |
| `infra/datahub/dev/recipes/iceberg_ingestion.yml` | **Create** | DataHub ingestion recipe |
| `pyproject.toml` | **Modify** | Add `pyiceberg[gcsfs,pyarrow]` |
| `infra/datahub/README.md` | **Update** | Iceberg integration docs |

---

## Verification Plan

```bash
# 1. Create shared network
docker network create dtheinfra-network

# 2. Start Iceberg catalog (independent)
cd infra/iceberg-catalog/dev && ./start-catalog.sh
curl http://localhost:8181/v1/config  # Should return catalog config

# 3. Start DataHub (independent)
cd infra/datahub/dev && ./start-datahub.sh
curl http://localhost:8080/health     # Should return healthy

# 4. Seed Iceberg tables
uv run python infra/datahub/dev/seed_iceberg_tables.py
curl http://localhost:8181/v1/namespaces  # Should list bronze, silver, gold

# 5. Verify data on GCS
gsutil ls gs://<bucket>/warehouse/bronze/raw_events/

# 6. Run DataHub ingestion
uv run datahub ingest -c infra/datahub/dev/recipes/iceberg_ingestion.yml

# 7. Check DataHub UI
open http://localhost:9002  # Search for "raw_events", verify schema

# 8. Schema evolution
# (run script to add column, re-ingest, verify in DataHub)

# 9. Independence test
cd infra/iceberg-catalog/dev && ./stop-catalog.sh  # DataHub still works
cd infra/datahub/dev && ./stop-datahub.sh           # Catalog still works
```
