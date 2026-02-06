# GCS Visual Guide for dtheinfra

**Last Updated:** 2026-02-06

This document provides visual diagrams to understand how GCS integrates with the dtheinfra platform.

---

## GCS Architecture Overview

```mermaid
graph TB
    subgraph "Google Cloud Platform"
        subgraph "GCS Bucket: dtheinfra-lakehouse-dev"
            W[warehouse/]
            W --> Bronze[bronze/]
            W --> Silver[silver/]
            W --> Gold[gold/]
        end

        SA[Service Account<br/>iceberg-catalog@project.iam]
        IAM[IAM Policy:<br/>roles/storage.admin]
    end

    subgraph "Local Development"
        LC[Lakekeeper<br/>:8181]
        PG[(PostgreSQL<br/>Catalog Metadata)]
        Key[Service Account Key<br/>JSON file]
    end

    subgraph "Data Engines"
        Spark[Spark Jobs]
        Flink[Flink Streams]
        PyIce[PyIceberg Scripts]
    end

    Key -.-> SA
    SA --> IAM
    IAM --> W
    LC --> Key
    LC --> PG
    LC --> W

    Spark --> LC
    Flink --> LC
    PyIce --> LC

    style W fill:#E3F2FD
    style Bronze fill:#FFEBEE
    style Silver fill:#FFF3E0
    style Gold fill:#E8F5E9
    style SA fill:#FFF9C4
```

---

## Medallion Architecture with GCS

```mermaid
flowchart LR
    subgraph Sources
        K[Kafka Topics]
        API[REST APIs]
        DB[Databases]
    end

    subgraph "GCS: Bronze Layer"
        B1[gs://.../warehouse/bronze/]
        B2[Raw Data<br/>Source Schema<br/>Iceberg Tables]
    end

    subgraph "GCS: Silver Layer"
        S1[gs://.../warehouse/silver/]
        S2[Cleaned Data<br/>Validated Schema<br/>Iceberg Tables]
    end

    subgraph "GCS: Gold Layer"
        G1[gs://.../warehouse/gold/]
        G2[Aggregated Metrics<br/>Business Schema<br/>Iceberg Tables]
    end

    subgraph Consumers
        BI[BI Tools]
        API2[Data APIs]
        ML[ML Models]
    end

    K --> B1
    API --> B1
    DB --> B1

    B1 --> |Flink/Spark<br/>Transformations| S1
    S1 --> |dbt<br/>Aggregations| G1

    G1 --> BI
    G1 --> API2
    G1 --> ML

    style B1 fill:#FFEBEE
    style S1 fill:#FFF3E0
    style G1 fill:#E8F5E9
```

---

## Iceberg Table Structure on GCS

```mermaid
graph TB
    subgraph "GCS Bucket"
        subgraph "warehouse/bronze/raw_events/"
            Meta[metadata/]
            Data[data/]

            Meta --> V1[v1.metadata.json]
            Meta --> V2[v2.metadata.json]
            Meta --> Snap[snap-123.avro]
            Meta --> Man[manifest-456.avro]

            Data --> P1[year=2026/]
            P1 --> M1[month=02/]
            M1 --> D1[day=06/]
            D1 --> F1[00000-0-abc123.parquet]
        end
    end

    Catalog[Iceberg Catalog<br/>Lakekeeper]
    Reader[Data Reader<br/>Spark/Flink]

    Catalog -.Stores current version.-> Meta
    Reader -.Reads metadata.-> Meta
    Reader -.Reads data files.-> Data

    style Meta fill:#FFF3E0
    style Data fill:#E3F2FD
    style V2 fill:#4CAF50
```

**Structure breakdown:**
- `metadata/` - Iceberg metadata files (JSON, Avro manifests)
- `data/` - Parquet data files organized by partition keys
- `vN.metadata.json` - Table schema, partitioning, snapshots
- `snap-*.avro` - Snapshot manifest list
- `manifest-*.avro` - File-level manifest with statistics

---

## Data Write Flow (Iceberg + GCS)

```mermaid
sequenceDiagram
    participant App as Application<br/>(Spark/Flink)
    participant IC as Iceberg Catalog<br/>(Lakekeeper)
    participant GCS as Google Cloud Storage
    participant PG as PostgreSQL<br/>(Catalog DB)

    Note over App,PG: Table Creation
    App->>IC: CREATE TABLE bronze.events
    IC->>PG: Store table metadata
    IC->>GCS: Write v1.metadata.json
    IC-->>App: Table created

    Note over App,PG: Data Ingestion
    App->>GCS: Write Parquet files<br/>(00000-0-*.parquet)
    App->>App: Build manifest list

    Note over App,PG: Commit Transaction
    App->>IC: COMMIT (snapshot)
    IC->>GCS: Write manifest files<br/>(snap-*.avro, manifest-*.avro)
    IC->>GCS: Write v2.metadata.json (atomic)
    IC->>PG: Update current snapshot pointer
    IC-->>App: Commit successful

    Note over App,PG: Data Read
    App->>IC: SELECT FROM bronze.events
    IC->>PG: Get current snapshot
    IC->>GCS: Read v2.metadata.json
    IC->>GCS: Read manifest files
    IC-->>App: Return file list
    App->>GCS: Read Parquet files
    GCS-->>App: Data rows
```

---

## Authentication Flow

```mermaid
flowchart TB
    subgraph "Local Machine"
        App[Application<br/>Lakekeeper/Spark]
        Env[Environment Variable<br/>GOOGLE_APPLICATION_CREDENTIALS]
        Key[Service Account Key<br/>JSON file]
    end

    subgraph "Google Cloud Platform"
        Auth[OAuth Token Service]
        IAM[IAM Service]
        GCS[Google Cloud Storage]
    end

    Env -.Points to.-> Key
    App --> Env
    App --> |1. Read key file| Key
    App --> |2. Request token| Auth
    Auth --> |3. Validate service account| IAM
    IAM --> |4. Return access token| Auth
    Auth --> |5. Access token| App
    App --> |6. API call with token| GCS
    GCS --> |7. Verify token| IAM
    GCS --> |8. Check permissions| IAM
    GCS --> |9. Grant/deny access| App

    style Key fill:#FFF9C4
    style App fill:#E3F2FD
    style GCS fill:#E8F5E9
```

**Key points:**
1. Application reads service account key from file
2. Exchanges key for OAuth access token
3. Uses token for all GCS API calls
4. Token expires after 1 hour (auto-refreshed by SDK)

---

## Storage Class Lifecycle

```mermaid
flowchart LR
    Write[Write to GCS]
    Standard[Standard Storage<br/>$0.020/GB/month<br/>Free reads]
    Nearline[Nearline Storage<br/>$0.010/GB/month<br/>30-day minimum]
    Coldline[Coldline Storage<br/>$0.004/GB/month<br/>90-day minimum]
    Archive[Archive Storage<br/>$0.0012/GB/month<br/>365-day minimum]

    Write --> Standard
    Standard --> |age: 30 days| Nearline
    Nearline --> |age: 90 days| Coldline
    Coldline --> |age: 365 days| Archive

    style Standard fill:#4CAF50
    style Nearline fill:#FFC107
    style Coldline fill:#2196F3
    style Archive fill:#9E9E9E
```

**Lifecycle policy example:**
```json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 30, "matchesPrefix": ["warehouse/bronze/"]}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {"age": 90, "matchesPrefix": ["warehouse/bronze/"]}
      }
    ]
  }
}
```

---

## GCS vs S3 Cost Comparison (Analytics Workload)

```mermaid
graph TB
    subgraph "Monthly Costs (1TB storage, 100M reads)"
        S3_Storage[S3 Storage: $23]
        S3_Reads[S3 Reads: $40]
        S3_Writes[S3 Writes: $5]
        S3_Egress[S3 Egress: $9]
        S3_Total[S3 Total: $77]

        GCS_Storage[GCS Storage: $20]
        GCS_Reads[GCS Reads: $0 FREE]
        GCS_Writes[GCS Writes: $5]
        GCS_Egress[GCS Egress: $12]
        GCS_Total[GCS Total: $37]
    end

    S3_Storage --> S3_Total
    S3_Reads --> S3_Total
    S3_Writes --> S3_Total
    S3_Egress --> S3_Total

    GCS_Storage --> GCS_Total
    GCS_Reads --> GCS_Total
    GCS_Writes --> GCS_Total
    GCS_Egress --> GCS_Total

    style S3_Total fill:#FFEBEE
    style GCS_Total fill:#E8F5E9
    style GCS_Reads fill:#4CAF50
```

**Key insight:** GCS is 52% cheaper for analytics workloads due to FREE read operations.

---

## dtheinfra Network Architecture

```mermaid
graph TB
    subgraph "Docker Network: dtheinfra-network"
        subgraph "Iceberg Catalog Stack"
            LK[Lakekeeper<br/>lakekeeper:8181]
            PG[(PostgreSQL<br/>postgres:5432)]
        end

        subgraph "DataHub Stack"
            DH_GMS[DataHub GMS<br/>datahub-gms:8080]
            DH_Frontend[DataHub Frontend<br/>datahub-frontend:9002]
        end

        subgraph "Data Processing"
            Spark[Spark Master<br/>spark-master:7077]
            Flink[Flink JobManager<br/>flink-jobmanager:8081]
        end
    end

    subgraph "Google Cloud Platform"
        GCS[GCS Bucket<br/>gs://dtheinfra-lakehouse-dev]
    end

    LK <--> PG
    LK --> GCS
    DH_GMS --> LK
    Spark --> LK
    Flink --> LK

    style LK fill:#FFF3E0
    style GCS fill:#E8F5E9
    style DH_GMS fill:#E3F2FD
```

---

## Service Account Permissions Model

```mermaid
graph LR
    subgraph "Service Accounts"
        SA1[iceberg-catalog SA]
        SA2[data-ingestion SA]
        SA3[analytics SA]
    end

    subgraph "GCS Buckets"
        B1[dtheinfra-lakehouse-dev]
        B2[dtheinfra-logs]
    end

    subgraph "IAM Roles"
        R1[roles/storage.admin<br/>Full control]
        R2[roles/storage.objectCreator<br/>Write-only]
        R3[roles/storage.objectViewer<br/>Read-only]
    end

    SA1 --> R1
    R1 --> B1

    SA2 --> R2
    R2 --> B1

    SA3 --> R3
    R3 --> B1

    style R1 fill:#FFEBEE
    style R2 fill:#FFF3E0
    style R3 fill:#E8F5E9
```

**Role assignments:**
- **Iceberg Catalog**: `storage.admin` (needs to manage metadata)
- **Data Ingestion**: `storage.objectCreator` (write-only for security)
- **Analytics Jobs**: `storage.objectViewer` (read-only for security)

---

## Bucket Organization Pattern

```
gs://dtheinfra-lakehouse-dev/
├── warehouse/                      # Iceberg warehouse root
│   ├── bronze/                     # Raw data layer
│   │   ├── raw_events/             # Iceberg table
│   │   │   ├── metadata/           # Table metadata
│   │   │   │   ├── v1.metadata.json
│   │   │   │   ├── v2.metadata.json
│   │   │   │   ├── snap-1234.avro
│   │   │   │   └── manifest-5678.avro
│   │   │   └── data/               # Parquet files
│   │   │       └── year=2026/
│   │   │           └── month=02/
│   │   │               └── 00000-0-abc.parquet
│   │   └── raw_users/              # Another table
│   │       └── ...
│   ├── silver/                     # Cleaned data layer
│   │   ├── cleaned_events/
│   │   └── enriched_users/
│   └── gold/                       # Aggregated data layer
│       ├── user_metrics/
│       └── daily_aggregations/
├── tmp/                            # Temporary files (auto-deleted)
└── backups/                        # Manual backups
```

**Lifecycle policies:**
- `warehouse/bronze/`: Transition to Nearline after 30 days
- `warehouse/silver/`: Keep in Standard
- `warehouse/gold/`: Keep in Standard
- `tmp/`: Delete after 7 days

---

## Query Performance Optimization

```mermaid
flowchart TB
    Query[SQL Query:<br/>SELECT * FROM events<br/>WHERE date = '2026-02-06']

    subgraph "Iceberg Metadata Pruning"
        M1[Read v2.metadata.json]
        M2[Parse partition spec]
        M3[Filter manifests by date]
        M4[Only relevant manifests]
    end

    subgraph "GCS Data Access"
        G1[Read only filtered files:<br/>year=2026/month=02/day=06/]
        G2[Skip other partitions]
    end

    Result[Fast Query Results]

    Query --> M1
    M1 --> M2
    M2 --> M3
    M3 --> M4
    M4 --> G1
    G2 -.Avoided scan.-> G2
    G1 --> Result

    style M4 fill:#4CAF50
    style G1 fill:#4CAF50
    style G2 fill:#BDBDBD
```

**Performance gains:**
- Iceberg metadata filtering avoids scanning irrelevant files
- GCS free reads on Standard class (no cost penalty for queries)
- Columnar Parquet format allows column pruning
- Result: 100x faster than full table scan

---

## Troubleshooting Decision Tree

```mermaid
flowchart TD
    Start[GCS Access Issue]
    Start --> Check1{Can list buckets?}

    Check1 -->|No| Auth[Authentication Problem]
    Check1 -->|Yes| Check2{Can list objects in bucket?}

    Auth --> Fix1[Check GOOGLE_APPLICATION_CREDENTIALS]
    Auth --> Fix2[Verify key file is valid JSON]
    Auth --> Fix3[Test: gcloud auth activate-service-account]

    Check2 -->|No| Perm[Permission Problem]
    Check2 -->|Yes| Check3{Can upload files?}

    Perm --> Fix4[Check IAM policy: gsutil iam get gs://bucket]
    Perm --> Fix5[Grant role: gsutil iam ch serviceAccount:SA:roles/storage.objectViewer]

    Check3 -->|No| Write[Write Permission Problem]
    Check3 -->|Yes| Check4{Lakekeeper working?}

    Write --> Fix6[Grant role: gsutil iam ch serviceAccount:SA:roles/storage.objectCreator]

    Check4 -->|No| Config[Lakekeeper Config Problem]
    Check4 -->|Yes| Success[All Working!]

    Config --> Fix7[Check infra/iceberg-catalog/dev/.env]
    Config --> Fix8[Verify GCS_WAREHOUSE_URI]
    Config --> Fix9[Check docker logs lakekeeper]

    style Success fill:#4CAF50
    style Auth fill:#FFEBEE
    style Perm fill:#FFEBEE
    style Write fill:#FFEBEE
    style Config fill:#FFEBEE
```

---

## Summary: Why GCS for dtheinfra?

```mermaid
mindmap
  root((GCS for<br/>dtheinfra))
    Dev/Prod Parity
      Real GCS in dev
      No MinIO emulation
      Same auth flow
    Cost Efficiency
      Free GET requests
      50% cheaper for analytics
      No minimum object size
    Iceberg ACID
      Native FileIO support
      Object versioning
      Strong consistency
    Multi-Cloud
      Avoid AWS lock-in
      GCP expertise
      BigQuery integration future
```

---

## Next Steps

For detailed information, see:
- [GCS Architecture Overview](./google-cloud-storage.md) - Comprehensive concepts and comparisons
- [GCS Operations Guide](../operations/gcs-operations.md) - Setup and CLI usage
- [GCS Quick Reference](../operations/gcs-quick-reference.md) - S3 to GCS translation
- [ADR 0002: Use GCS for Storage](./adr/0002-use-gcs-for-storage.md) - Decision rationale

---

**Legend for diagrams:**
- Bronze fill: Raw/bronze layer data
- Silver fill: Cleaned/silver layer data
- Gold fill: Aggregated/gold layer data
- Green fill: Successful/optimal state
- Red fill: Error/problem state
- Gray fill: Avoided/skipped operations
