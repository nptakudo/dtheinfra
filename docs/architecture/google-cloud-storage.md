# Google Cloud Storage (GCS) Overview

**Last Updated:** 2026-02-06
**Audience:** Platform engineers familiar with AWS S3

## Table of Contents

1. [What is GCS](#what-is-gcs)
2. [GCS vs S3 Comparison](#gcs-vs-s3-comparison)
3. [Core Concepts](#core-concepts)
4. [Why GCS for dtheinfra](#why-gcs-for-dtheinfra)
5. [Storage Architecture](#storage-architecture)

---

## What is GCS

Google Cloud Storage (GCS) is Google Cloud's object storage service, analogous to AWS S3. It provides globally unified, scalable, and durable object storage for unstructured data.

### Key Features

- **Global Consistency**: Strongly consistent for all operations (read-after-write, list-after-write)
- **Automatic Replication**: Geo-redundant storage across regions
- **Scalability**: Unlimited storage, no bucket size limits
- **Integration**: Native integration with BigQuery, Dataproc, Dataflow, and Iceberg
- **Pricing**: Pay only for what you use, no minimum object size charges

### When to Use GCS

Use GCS when you need:
- **Data Lake Storage**: Raw data ingestion (bronze layer)
- **Lakehouse Foundation**: Iceberg table storage with ACID guarantees
- **Archive Storage**: Long-term retention with lifecycle policies
- **Analytics Workloads**: Direct querying via BigQuery External Tables
- **Multi-Cloud Strategy**: Avoiding AWS vendor lock-in

---

## GCS vs S3 Comparison

### Terminology Mapping

| Concept | AWS S3 | Google Cloud Storage |
|---------|--------|---------------------|
| Container | Bucket | Bucket |
| Stored item | Object | Object |
| Object path | Key | Object name |
| Metadata | Object metadata | Custom metadata |
| Permissions | IAM policies + ACLs | IAM policies + ACLs |
| Lifecycle rules | S3 Lifecycle | Object Lifecycle Management |
| Versioning | S3 Versioning | Object Versioning |
| Multi-part upload | Multipart Upload | Resumable uploads |
| Signed URL | Pre-signed URL | Signed URL |

### Authentication Comparison

#### AWS S3
```python
# S3 uses IAM roles or access keys
import boto3

# Option 1: IAM Role (EC2/ECS)
s3 = boto3.client('s3')

# Option 2: Access Key
s3 = boto3.client(
    's3',
    aws_access_key_id='AKIAIOSFODNN7EXAMPLE',
    aws_secret_access_key='wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
)
```

#### GCS
```python
# GCS uses service accounts or ADC
from google.cloud import storage

# Option 1: Application Default Credentials (GCE/GKE)
client = storage.Client()

# Option 2: Service Account Key
client = storage.Client.from_service_account_json(
    '/path/to/service-account-key.json'
)

# Option 3: Environment variable
# export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
client = storage.Client()
```

### API/SDK Differences

| Operation | S3 (boto3) | GCS (google-cloud-storage) |
|-----------|------------|----------------------------|
| List objects | `s3.list_objects_v2(Bucket='bucket')` | `client.list_blobs('bucket')` |
| Upload file | `s3.upload_file('file.txt', 'bucket', 'key')` | `bucket.blob('key').upload_from_filename('file.txt')` |
| Download file | `s3.download_file('bucket', 'key', 'file.txt')` | `bucket.blob('key').download_to_filename('file.txt')` |
| Delete object | `s3.delete_object(Bucket='bucket', Key='key')` | `bucket.blob('key').delete()` |
| Copy object | `s3.copy_object(...)` | `bucket.copy_blob(source_blob, dest_bucket, new_name)` |

### CLI Comparison

| Operation | AWS CLI | gsutil |
|-----------|---------|--------|
| List buckets | `aws s3 ls` | `gsutil ls` |
| List objects | `aws s3 ls s3://bucket/path/` | `gsutil ls gs://bucket/path/` |
| Copy file | `aws s3 cp file.txt s3://bucket/` | `gsutil cp file.txt gs://bucket/` |
| Sync directory | `aws s3 sync ./dir s3://bucket/` | `gsutil -m rsync -r ./dir gs://bucket/` |
| Remove object | `aws s3 rm s3://bucket/key` | `gsutil rm gs://bucket/key` |
| Make public | `aws s3api put-object-acl --acl public-read` | `gsutil acl ch -u AllUsers:R gs://bucket/object` |

### Pricing Model Differences

#### Storage Costs

| Tier | S3 | GCS | Use Case |
|------|----|----|----------|
| Hot | Standard | Standard | Active data, < 30 days |
| Warm | Standard-IA | Nearline | Infrequent access, < 90 days |
| Cold | Glacier Flexible | Coldline | Rare access, < 1 year |
| Archive | Glacier Deep | Archive | Compliance, > 1 year |

**Key Difference**: GCS doesn't charge for retrieval on Standard class (S3 charges for GET requests).

#### Data Transfer Costs

| Transfer Type | S3 | GCS |
|---------------|----|----|
| Ingress (upload) | Free | Free |
| Egress within region | Free | Free |
| Egress to internet | $0.09/GB | $0.12/GB (first 1 TB) |
| Cross-region | $0.02/GB | $0.01/GB (same continent) |

#### Operations Costs

| Operation | S3 | GCS |
|-----------|----|----|
| Write (PUT/COPY/POST) | $0.005 per 1,000 | $0.05 per 10,000 (Standard) |
| Read (GET/SELECT) | $0.0004 per 1,000 | Free for Standard |
| List (LIST) | $0.005 per 1,000 | $0.05 per 10,000 |

**Cost Optimization Tip**: GCS Standard has free reads, making it ideal for analytics workloads with frequent access.

### Access Pattern Comparison

#### Signed URLs

**S3 Pre-signed URL:**
```python
import boto3

s3 = boto3.client('s3')
url = s3.generate_presigned_url(
    'get_object',
    Params={'Bucket': 'bucket', 'Key': 'key'},
    ExpiresIn=3600  # 1 hour
)
```

**GCS Signed URL:**
```python
from google.cloud import storage

client = storage.Client()
bucket = client.bucket('bucket')
blob = bucket.blob('key')

url = blob.generate_signed_url(
    version='v4',
    expiration=3600,  # 1 hour
    method='GET'
)
```

#### IAM Policies

**S3 Bucket Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {"AWS": "arn:aws:iam::123456789012:user/Alice"},
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::bucket/*"
    }
  ]
}
```

**GCS IAM Policy:**
```bash
# Grant user storage.objectViewer role on bucket
gsutil iam ch user:alice@example.com:roles/storage.objectViewer gs://bucket

# Grant service account storage.admin role
gcloud storage buckets add-iam-policy-binding gs://bucket \
    --member=serviceAccount:sa@project.iam.gserviceaccount.com \
    --role=roles/storage.admin
```

**Key Difference**: GCS uses predefined roles (objectViewer, objectCreator, admin) while S3 uses granular permissions.

---

## Core Concepts

### Buckets

Containers for objects, similar to S3 buckets.

**Bucket Naming Rules:**
- Globally unique across all GCP projects
- 3-63 characters, lowercase letters, numbers, hyphens
- Cannot start/end with hyphen
- Cannot contain "google" or misspellings
- Examples: `dtheinfra-lakehouse`, `prod-bronze-layer`

**Bucket Configuration:**
```bash
# Create bucket with specific location and storage class
gsutil mb -l US-CENTRAL1 -c STANDARD gs://dtheinfra-lakehouse

# Create multi-region bucket (higher availability)
gsutil mb -l US -c STANDARD gs://dtheinfra-lakehouse-prod
```

### Objects

Files stored in buckets, identified by their name (path).

**Object Names:**
- Can be up to 1024 bytes
- Support `/` for hierarchical organization (logical, not physical)
- Case-sensitive
- Examples: `warehouse/bronze/events/year=2026/month=02/data.parquet`

**Object Metadata:**
- **Standard metadata**: Content-Type, Cache-Control, Content-Encoding
- **Custom metadata**: User-defined key-value pairs
- **System metadata**: Size, MD5 hash, creation time, storage class

### Storage Classes

GCS offers four storage classes optimized for different access patterns.

```mermaid
graph LR
    A[Standard] -->|Auto-transition| B[Nearline]
    B -->|Auto-transition| C[Coldline]
    C -->|Auto-transition| D[Archive]

    style A fill:#4CAF50
    style B fill:#FFC107
    style C fill:#2196F3
    style D fill:#9E9E9E
```

| Class | Min Storage | Retrieval Cost | Use Case | dtheinfra Usage |
|-------|-------------|----------------|----------|-----------------|
| **Standard** | None | None | Frequent access | Bronze, Silver, Gold layers |
| **Nearline** | 30 days | $0.01/GB | Monthly access | Archived partitions |
| **Coldline** | 90 days | $0.02/GB | Quarterly access | Compliance data |
| **Archive** | 365 days | $0.05/GB | Yearly access | Legal hold |

**Lifecycle Transition Example:**
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
      },
      {
        "action": {"type": "Delete"},
        "condition": {"age": 365, "matchesPrefix": ["warehouse/bronze/tmp/"]}
      }
    ]
  }
}
```

### Access Control

GCS supports two permission models:

#### 1. IAM (Recommended)

Uniform bucket-level and project-level access control.

**Predefined Roles:**
- `roles/storage.objectViewer` - Read objects
- `roles/storage.objectCreator` - Create objects
- `roles/storage.objectAdmin` - Full object control
- `roles/storage.admin` - Full bucket + object control

**Grant access:**
```bash
# Grant service account admin access
gsutil iam ch serviceAccount:iceberg@project.iam.gserviceaccount.com:roles/storage.admin \
    gs://dtheinfra-lakehouse
```

#### 2. ACLs (Legacy)

Object-level access control (avoid for new buckets).

```bash
# Make object publicly readable (legacy)
gsutil acl ch -u AllUsers:R gs://bucket/public-data.csv
```

**Best Practice**: Use IAM for uniform access control. Enable "Uniform bucket-level access" when creating buckets.

### Service Accounts

GCS authentication uses service accounts (SA) for application access.

**Service Account Anatomy:**
- **Email**: `sa-name@project-id.iam.gserviceaccount.com`
- **Key File**: JSON file containing private key for authentication
- **Roles**: Assigned via IAM bindings

**Create Service Account:**
```bash
# Create service account
gcloud iam service-accounts create iceberg-catalog \
    --description="Iceberg catalog GCS access" \
    --display-name="Iceberg Catalog SA"

# Grant Storage Admin role on bucket
gsutil iam ch serviceAccount:iceberg-catalog@project.iam.gserviceaccount.com:roles/storage.admin \
    gs://dtheinfra-lakehouse

# Create key file
gcloud iam service-accounts keys create ~/iceberg-sa-key.json \
    --iam-account=iceberg-catalog@project.iam.gserviceaccount.com
```

**Key Security:**
- Never commit key files to git (add to `.gitignore`)
- Rotate keys every 90 days
- Use workload identity in GKE (avoid key files)
- Store keys in secret managers (Vault, GCP Secret Manager)

---

## Why GCS for dtheinfra

### Design Rationale

```mermaid
graph TD
    A[dtheinfra Requirements] --> B{Storage Needs}
    B --> C[ACID Transactions]
    B --> D[Multi-Engine Access]
    B --> E[Cost Efficiency]
    B --> F[No Vendor Lock-in]

    C --> G[GCS + Iceberg]
    D --> G
    E --> G
    F --> G

    G --> H[Real GCS in Dev/Prod]

    style A fill:#E3F2FD
    style G fill:#4CAF50
    style H fill:#FFC107
```

### Key Benefits

1. **Real Cloud Storage in Development**
   - No MinIO emulation (S3-compatible but not identical)
   - Dev/prod parity for testing
   - Authentic authentication flows

2. **Iceberg Compatibility**
   - Native GCS FileIO implementation
   - Atomic commit operations via object versioning
   - Efficient metadata management

3. **Cost Optimization**
   - Free GET requests on Standard class (frequent reads)
   - Automatic lifecycle transitions
   - No minimum object size fees (unlike S3)

4. **Multi-Engine Support**
   - Spark (via Iceberg GCS FileIO)
   - Flink (via GCS connector)
   - PyIceberg (via fsspec)
   - Trino (via Iceberg connector)

5. **Global Consistency**
   - Strong read-after-write consistency
   - No eventual consistency issues
   - Reliable for transactional workloads

### Trade-offs Considered

| Aspect | S3 + MinIO | GCS |
|--------|-----------|-----|
| Local dev setup | Simple (Docker) | Requires GCP account |
| Cost (dev) | Free | ~$5-10/month for small workloads |
| Dev/prod parity | Low (emulation differences) | High (real GCS) |
| Team familiarity | High (AWS ubiquitous) | Medium (learning curve) |
| Authentication | IAM roles (simple) | Service accounts (keys required) |

**Decision**: Benefits of dev/prod parity and Iceberg compatibility outweigh the learning curve.

---

## Storage Architecture

### dtheinfra GCS Organization

```mermaid
graph TB
    subgraph "GCS Bucket: dtheinfra-lakehouse"
        A[warehouse/]
        A --> B[bronze/]
        A --> C[silver/]
        A --> D[gold/]

        B --> B1[raw_events/]
        B --> B2[raw_users/]

        C --> C1[cleaned_events/]
        C --> C2[enriched_users/]

        D --> D1[user_metrics/]
        D --> D2[aggregations/]

        B1 --> B1a[metadata/]
        B1 --> B1b[data/]

        B1a --> B1a1[v1.metadata.json]
        B1a --> B1a2[snap-*.avro]
        B1b --> B1b1[00000-0-*.parquet]
    end

    style A fill:#E3F2FD
    style B fill:#FFEBEE
    style C fill:#FFF3E0
    style D fill:#E8F5E9
```

### Warehouse Structure

The warehouse follows the Iceberg convention:

```
gs://dtheinfra-lakehouse/warehouse/
├── bronze/                          # Raw ingested data
│   ├── raw_events/                  # Iceberg table
│   │   ├── metadata/                # Iceberg metadata files
│   │   │   ├── v1.metadata.json     # Table metadata
│   │   │   ├── snap-123.avro        # Snapshot manifest list
│   │   │   └── manifest-456.avro    # File manifest
│   │   └── data/                    # Parquet data files
│   │       ├── year=2026/
│   │       │   └── month=02/
│   │       │       └── 00000-0-abc123.parquet
│   │       └── year=2026/
│   │           └── month=01/
│   │               └── 00001-1-def456.parquet
│   └── raw_users/
│       └── ...
├── silver/                          # Cleaned/validated data
│   ├── cleaned_events/
│   │   ├── metadata/
│   │   └── data/
│   └── enriched_users/
│       └── ...
└── gold/                            # Aggregated/business metrics
    ├── user_metrics/
    │   ├── metadata/
    │   └── data/
    └── daily_aggregations/
        └── ...
```

### Medallion Architecture

```mermaid
flowchart LR
    subgraph Sources
        S1[Kafka]
        S2[APIs]
        S3[Databases]
    end

    subgraph Bronze["Bronze Layer (Raw)"]
        B1[gs://.../warehouse/bronze/]
        B2[Schema: Source Schema]
        B3[Format: Iceberg + Parquet]
    end

    subgraph Silver["Silver Layer (Cleaned)"]
        Si1[gs://.../warehouse/silver/]
        Si2[Schema: Validated]
        Si3[Format: Iceberg + Parquet]
    end

    subgraph Gold["Gold Layer (Aggregated)"]
        G1[gs://.../warehouse/gold/]
        G2[Schema: Business Metrics]
        G3[Format: Iceberg + Parquet]
    end

    S1 --> Bronze
    S2 --> Bronze
    S3 --> Bronze
    Bronze --> |Flink/Spark| Silver
    Silver --> |dbt| Gold

    style Bronze fill:#FFEBEE
    style Silver fill:#FFF3E0
    style Gold fill:#E8F5E9
```

### Data Flow

```mermaid
sequenceDiagram
    participant App as Application
    participant IC as Iceberg Catalog<br/>(Lakekeeper)
    participant GCS as Google Cloud Storage
    participant PG as PostgreSQL<br/>(Catalog Metadata)

    App->>IC: CREATE TABLE bronze.events
    IC->>PG: Store table metadata
    IC->>GCS: Write metadata JSON<br/>gs://.../metadata/v1.json
    IC-->>App: Table created

    App->>IC: INSERT INTO bronze.events
    App->>GCS: Write Parquet files<br/>gs://.../data/*.parquet
    App->>IC: COMMIT (snapshot)
    IC->>GCS: Write manifest files
    IC->>GCS: Write new metadata JSON<br/>gs://.../metadata/v2.json
    IC->>PG: Update current snapshot
    IC-->>App: Commit successful

    App->>IC: SELECT FROM bronze.events
    IC->>PG: Get current snapshot
    IC->>GCS: Read metadata JSON
    IC-->>App: Return file list
    App->>GCS: Read Parquet files
    GCS-->>App: Data rows
```

### Bucket Configuration

**Production Setup:**
```bash
# Create production bucket (multi-region for HA)
gsutil mb -l US -c STANDARD gs://dtheinfra-lakehouse-prod

# Enable versioning (Iceberg requirement)
gsutil versioning set on gs://dtheinfra-lakehouse-prod

# Enable uniform bucket-level access
gsutil uniformbucketlevelaccess set on gs://dtheinfra-lakehouse-prod

# Set lifecycle policy
gsutil lifecycle set lifecycle.json gs://dtheinfra-lakehouse-prod
```

**Development Setup:**
```bash
# Create dev bucket (single region for cost)
gsutil mb -l US-CENTRAL1 -c STANDARD gs://dtheinfra-lakehouse-dev

# Enable versioning
gsutil versioning set on gs://dtheinfra-lakehouse-dev
```

---

## Next Steps

- [GCS Operations Guide](../operations/gcs-operations.md) - Setup instructions, CLI usage, best practices
- [Iceberg Catalog Integration](../../infra/iceberg-catalog/README.md) - Lakekeeper setup with GCS
- [Architecture Decision Record: GCS vs S3](./adr/0002-use-gcs-for-storage.md) - Detailed rationale

---

## References

- [GCS Documentation](https://cloud.google.com/storage/docs)
- [GCS vs S3 Feature Comparison](https://cloud.google.com/free/docs/aws-azure-gcp-service-comparison)
- [Apache Iceberg GCS FileIO](https://iceberg.apache.org/docs/latest/gcs/)
- [dtheinfra QUICKSTART](../../infra/QUICKSTART.md)
