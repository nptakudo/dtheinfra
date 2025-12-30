# Getting Started

This guide will help you set up your local development environment for the data platform.

## Prerequisites

Before you begin, ensure you have the following installed:

| Tool | Version | Purpose |
|------|---------|---------|
| Docker | 24.0+ | Container runtime |
| Docker Compose | 2.20+ | Multi-container orchestration |
| Python | 3.11+ | Primary development language |
| uv | Latest | Python package manager |
| JDK | 11+ | Scala/Spark development |
| sbt | 1.9+ | Scala build tool |
| Rust | 1.75+ | High-performance services |
| Terraform | 1.6+ | Infrastructure as Code |

### Installing Prerequisites

**macOS (using Homebrew):**
```bash
# Docker Desktop (includes Docker Compose)
brew install --cask docker

# Python and uv
brew install python@3.11
curl -LsSf https://astral.sh/uv/install.sh | sh

# JDK and sbt
brew install openjdk@11 sbt

# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Terraform
brew install terraform
```

## Initial Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd data-platform
```

### 2. Install Dependencies

```bash
make install
```

This will:
- Install Python dependencies via uv
- Set up pre-commit hooks

### 3. Start Local Infrastructure

Start the core services (recommended for most development):
```bash
make local-up-core
```

Or start the full stack (includes Spark, Flink, Airflow):
```bash
make local-up
```

### 4. Verify Services

Check that all services are running:
```bash
make local-ps
```

Access the web interfaces:
- MinIO Console: http://localhost:9001 (minioadmin/minioadmin)
- Kafka UI: http://localhost:8080
- Airflow: http://localhost:8084 (admin/admin) - full stack only

## Development Workflow

### Python Development

```bash
# Run linter
make py-lint

# Auto-format code
make py-format

# Run tests
make py-test
```

### Running a Python Service Locally

```bash
cd apps/services/data-api
uv run python -m uvicorn src.main:app --reload
```

### Scala Development

```bash
# Compile all Scala projects
make scala-compile

# Run tests
make scala-test

# Start sbt shell for interactive development
sbt
```

### Submitting a Spark Job Locally

```bash
# Open Spark shell with Iceberg support
cd local && make shell-spark
```

### Rust Development

```bash
# Build all Rust projects
make rust-build

# Run tests
make rust-test
```

## Configuration

The platform uses hierarchical configuration:

1. **Base configs** in `config/base/` (defaults)
2. **Environment configs** in `config/environments/` (overrides)
3. **Environment variables** (runtime overrides)

For local development, copy the example env file:
```bash
cp local/.env.example local/.env
```

## Common Tasks

### Create Kafka Topics

```bash
cd local
./init-scripts/kafka/create-topics.sh
```

### Connect to PostgreSQL

```bash
cd local && make shell-postgres
```

### View Logs

```bash
make local-logs
```

### Stop All Services

```bash
make local-down
```

### Clean Up (including volumes)

```bash
make local-down-clean
```

## Troubleshooting

### Port Already in Use

If you see port conflicts, check for existing containers:
```bash
docker ps -a
```

Stop and remove conflicting containers:
```bash
docker stop <container-id>
docker rm <container-id>
```

### Kafka Not Starting

Wait for Zookeeper to be healthy first:
```bash
docker logs dp-zookeeper
```

### MinIO Connection Issues

Ensure the buckets are created:
```bash
docker logs dp-minio-init
```

## Next Steps

- Read the [Architecture Overview](../architecture/data-flow.md)
- Explore the [ADRs](../architecture/adr/) for key design decisions
- Check out example DAGs in `apps/orchestration/dags/`
