# DTHEINFRA
End-to-end data platform with Lambda architecture (batch + streaming), built on AWS with a Lakehouse foundation (S3 + Apache Iceberg).

## Tech Stack

| Component | Technology |
|-----------|------------|
| Cloud | AWS (primary) + managed solutions |
| Streaming | Kafka (MSK), Flink |
| Batch | Spark (EMR Serverless) |
| Storage | S3 + Apache Iceberg |
| Transformation | dbt |
| Orchestration | Airflow |
| Languages | Python, Scala, Rust |
| IaC | Terraform |

## Project Structure

```
data-platform/
├── apps/                    # Deployable applications
│   ├── ingestion/          # Data ingestion services
│   ├── processing/         # Spark and Flink jobs
│   ├── transformation/     # dbt project
│   ├── orchestration/      # Airflow DAGs
│   └── services/           # Microservices (APIs)
├── libs/                    # Shared libraries
│   ├── python/             # Python packages
│   ├── scala/              # Scala libraries
│   └── rust/               # Rust crates
├── schemas/                 # Data contracts & schemas
│   ├── avro/               # Avro schemas
│   ├── protobuf/           # Protobuf definitions
│   └── contracts/          # Data contracts
├── infra/terraform/         # Infrastructure as Code
├── local/                   # Local development environment
├── config/                  # Configuration files
├── docs/                    # Documentation
├── scripts/                 # Utility scripts
└── tests/                   # Integration & E2E tests
```

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Python 3.11+
- [uv](https://github.com/astral-sh/uv) (Python package manager)
- JDK 11+ (for Scala)
- Rust 1.75+ (for Rust services)
- Terraform 1.6+ (for infrastructure)

### Local Development Setup

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd data-platform
   ```

2. **Install dependencies**
   ```bash
   make install
   ```

3. **Start local infrastructure**
   ```bash
   # Start core services (Kafka, MinIO, Postgres)
   make local-up-core

   # Or start full stack (includes Spark, Flink, Airflow)
   make local-up
   ```

4. **Verify services are running**
   ```bash
   make local-ps
   ```

### Available Services (Local)

| Service | URL | Credentials |
|---------|-----|-------------|
| MinIO Console | http://localhost:9001 | minioadmin / minioadmin |
| Kafka UI | http://localhost:8080 | - |
| Schema Registry | http://localhost:8081 | - |
| Spark Master UI | http://localhost:8082 | - |
| Flink Dashboard | http://localhost:8083 | - |
| Airflow | http://localhost:8084 | admin / admin |
| Iceberg REST Catalog | http://localhost:8181 | - |
| PostgreSQL | localhost:5432 | dataplatform / dataplatform |

## Development Commands

```bash
# Run all linters
make lint

# Format all code
make format

# Run all tests
make test

# Build all projects
make build

# View all available commands
make help
```

### Python Development

```bash
# Lint Python code
make py-lint

# Format Python code
make py-format

# Run Python tests
make py-test
```

### Scala Development

```bash
# Compile Scala projects
make scala-compile

# Run Scala tests
make scala-test

# Format Scala code
make scala-fmt
```

### Terraform

```bash
# Format Terraform code
make tf-fmt

# Validate all environments
make tf-validate
```

## Configuration

Configuration uses a hierarchical approach:

1. **Base configs** (`config/base/`) - Default values
2. **Environment overrides** (`config/environments/`) - Per-environment settings
3. **Environment variables** - Runtime overrides (prefix: `DP_`)

Example:
```bash
export DP_ENVIRONMENT=dev
export DP_KAFKA_BOOTSTRAP_SERVERS=kafka.dev.internal:9092
```

## Data Flow

```
Sources → Kafka → Flink (real-time) → Iceberg (Silver)
              ↓                            ↓
         Bronze (S3) → Spark (batch) → dbt → Gold (S3)
                                              ↓
                                        Data API / BI
```

## License

MIT
