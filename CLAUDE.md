# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

DTHEINFRA is an end-to-end data platform with Lambda architecture (batch + streaming), built on AWS with a Lakehouse foundation using S3 + Apache Iceberg. This is a polyglot codebase using Python, Scala, and Rust.

## Build & Development Commands

```bash
# Install all dependencies (Python via uv, pre-commit hooks)
make install

# Start local infrastructure
make local-up-core    # Core services only (Kafka, MinIO, Postgres) - faster startup
make local-up         # Full stack (includes Spark, Flink, Airflow)
make local-down       # Stop local environment
make local-ps         # Check running services

# Run all linters/formatters/tests
make lint             # All linters (Python, Rust, Terraform)
make format           # All formatters
make test             # All tests
make build            # Build Scala and Rust projects
```

### Language-Specific Commands

**Python** (uses `uv` package manager):
```bash
make py-lint          # ruff check + mypy
make py-format        # ruff format
make py-test          # pytest
uv run pytest path/to/test.py -k test_name  # Run single test
```

**Scala** (uses `sbt`):
```bash
make scala-compile
make scala-test
make scala-fmt
sbt "testOnly *TestClassName"  # Run single test class
```

**Rust** (uses `cargo`):
```bash
make rust-build
make rust-test
make rust-fmt
make rust-lint        # cargo clippy
cargo test test_name  # Run single test
```

**Terraform**:
```bash
make tf-fmt
make tf-validate
```

## Architecture

### Data Flow (Lambda Architecture)
```
Sources → Kafka → Flink (real-time) → Iceberg (Silver)
              ↓                            ↓
         Bronze (S3) → Spark (batch) → dbt → Gold (S3)
                                              ↓
                                        Data API / BI
```

### Key Directories

- `platform/processing/spark-jobs/` - Spark ETL jobs (Bronze → Silver → Gold layers)
- `platform/processing/flink-jobs/` - Real-time streaming jobs
- `platform/ingestion/stream-ingestors/` - Kafka producers (Rust)
- `platform/orchestration/` - Airflow DAGs
- `platform/transformation/` - dbt project
- `libs/python/` - Shared Python packages
- `libs/scala/` - Spark, Flink, Iceberg utilities (`sparkUtils`, `flinkUtils`, `icebergUtils`)
- `libs/rust/` - Common Rust crates (`dp-common`, `dp-kafka`)
- `schemas/avro/` - Avro schema definitions for data contracts
- `config/base/` - Default configurations (kafka.yaml, iceberg.yaml, logging.yaml)
- `config/environments/` - Environment-specific overrides
- `infra/terraform/` - IaC modules (storage, networking, governance)
- `local/` - Docker Compose files for local development

### Scala Build Structure (build.sbt)

Six main modules:
- **Shared Libraries**: `sparkUtils`, `flinkUtils`, `icebergUtils`
- **Spark ETL**: `etlBronze`, `etlSilver`, `etlGold`
- **Flink Streaming**: `realtimeAggregator`, `eventEnricher`

### Rust Workspace (Cargo.toml)

Three crates:
- `libs/rust/dp-common` - Common utilities
- `libs/rust/dp-kafka` - Kafka client wrapper
- `apps/ingestion/stream-ingestors/kafka-producer` - Kafka producer service

## Configuration System

Hierarchical configuration with environment variable overrides:

1. Base configs in `config/base/`
2. Environment overrides in `config/environments/`
3. Runtime overrides via `DP_` prefixed environment variables

Example: `DP_KAFKA_BOOTSTRAP_SERVERS=kafka.dev:9092`

## Local Services

| Service | Port | Purpose |
|---------|------|---------|
| RustFS | 9001 | S3-compatible storage (admin: minioadmin/minioadmin) |
| Kafka UI | 8080 | Kafka admin dashboard |
| Schema Registry | 8081 | Avro schema versioning |
| Spark Master | 8082 | Spark cluster UI |
| Flink Dashboard | 8083 | Flink cluster UI |
| Airflow | 8084 | Workflow orchestration (admin/admin) |
| Iceberg REST | 8181 | Table catalog |
| PostgreSQL | 5432 | Metadata DB (dataplatform/dataplatform) |

## Key Technology Decisions

- **Apache Iceberg** as table format (over Delta Lake/Hudi) for engine-agnostic access (Spark, Flink, Trino), AWS Glue integration, and advanced features (hidden partitioning, time travel)
- **uv** for Python package management (not pip/poetry)
- **REST Catalog** for local Iceberg development;
