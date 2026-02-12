# GCS Quick Reference for S3 Users

**Last Updated:** 2026-02-06
**Audience:** Engineers familiar with AWS S3

This is a quick lookup guide for engineers transitioning from S3 to GCS. For comprehensive documentation, see [GCS Architecture Overview](../architecture/google-cloud-storage.md) and [GCS Operations Guide](./gcs-operations.md).

---

## CLI Command Translation

| Task | S3 (aws s3) | GCS (gsutil) |
|------|-------------|--------------|
| List buckets | `aws s3 ls` | `gsutil ls` |
| List objects | `aws s3 ls s3://bucket/path/` | `gsutil ls gs://bucket/path/` |
| List recursively | `aws s3 ls s3://bucket/ --recursive` | `gsutil ls -r gs://bucket/` |
| Upload file | `aws s3 cp file.txt s3://bucket/` | `gsutil cp file.txt gs://bucket/` |
| Upload directory | `aws s3 cp dir/ s3://bucket/ --recursive` | `gsutil -m cp -r dir/ gs://bucket/` |
| Download file | `aws s3 cp s3://bucket/file.txt ./` | `gsutil cp gs://bucket/file.txt ./` |
| Download directory | `aws s3 cp s3://bucket/dir/ ./ --recursive` | `gsutil -m cp -r gs://bucket/dir/ ./` |
| Sync directory | `aws s3 sync ./dir s3://bucket/` | `gsutil -m rsync -r ./dir gs://bucket/` |
| Delete object | `aws s3 rm s3://bucket/file.txt` | `gsutil rm gs://bucket/file.txt` |
| Delete directory | `aws s3 rm s3://bucket/dir/ --recursive` | `gsutil -m rm -r gs://bucket/dir/` |
| Make bucket | `aws s3 mb s3://bucket` | `gsutil mb gs://bucket` |
| Remove bucket | `aws s3 rb s3://bucket` | `gsutil rb gs://bucket` |
| Object size | `aws s3 ls --summarize s3://bucket/file.txt` | `gsutil du gs://bucket/file.txt` |
| Object metadata | `aws s3api head-object --bucket bucket --key file.txt` | `gsutil stat gs://bucket/file.txt` |

**Key differences:**
- GCS uses `-m` flag for parallel operations (S3 parallelizes by default)
- GCS uses `-r` for recursive, S3 uses `--recursive`
- S3 has `s3` and `s3api` commands, GCS has only `gsutil`

---

## Python SDK Translation

### Client Initialization

**S3 (boto3):**
```python
import boto3

# Using IAM role (implicit)
s3 = boto3.client('s3')

# Using access keys
s3 = boto3.client('s3',
    aws_access_key_id='AKIAIOSFODNN7EXAMPLE',
    aws_secret_access_key='wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY'
)
```

**GCS (google-cloud-storage):**
```python
from google.cloud import storage

# Using ADC (implicit)
client = storage.Client()

# Using service account key
client = storage.Client.from_service_account_json(
    '/path/to/service-account-key.json'
)
```

### List Objects

**S3:**
```python
response = s3.list_objects_v2(Bucket='bucket', Prefix='path/')
for obj in response.get('Contents', []):
    print(obj['Key'])
```

**GCS:**
```python
bucket = client.bucket('bucket')
blobs = bucket.list_blobs(prefix='path/')
for blob in blobs:
    print(blob.name)
```

### Upload File

**S3:**
```python
s3.upload_file('/local/file.txt', 'bucket', 'path/file.txt')
```

**GCS:**
```python
bucket = client.bucket('bucket')
blob = bucket.blob('path/file.txt')
blob.upload_from_filename('/local/file.txt')
```

### Download File

**S3:**
```python
s3.download_file('bucket', 'path/file.txt', '/local/file.txt')
```

**GCS:**
```python
bucket = client.bucket('bucket')
blob = bucket.blob('path/file.txt')
blob.download_to_filename('/local/file.txt')
```

### Delete Object

**S3:**
```python
s3.delete_object(Bucket='bucket', Key='path/file.txt')
```

**GCS:**
```python
bucket = client.bucket('bucket')
blob = bucket.blob('path/file.txt')
blob.delete()
```

### Generate Signed URL

**S3:**
```python
url = s3.generate_presigned_url('get_object',
    Params={'Bucket': 'bucket', 'Key': 'file.txt'},
    ExpiresIn=3600
)
```

**GCS:**
```python
bucket = client.bucket('bucket')
blob = bucket.blob('file.txt')
url = blob.generate_signed_url(version='v4', expiration=3600, method='GET')
```

---

## Terminology Translation

| S3 Term | GCS Equivalent | Notes |
|---------|----------------|-------|
| Bucket | Bucket | Same concept |
| Object | Object | Same concept |
| Key | Object name | S3 "key" = GCS "name" |
| Region | Location | Similar but different names |
| S3 Standard | Standard | Same tier name |
| S3 Standard-IA | Nearline | Infrequent access |
| S3 Glacier | Coldline | Rarely accessed |
| S3 Glacier Deep | Archive | Long-term archive |
| IAM policy | IAM policy | Same concept, different syntax |
| Bucket policy | IAM binding | Attached to bucket |
| ACL | ACL | Same concept (legacy in both) |
| Pre-signed URL | Signed URL | Same purpose |
| Multipart upload | Resumable upload | Different implementation |
| S3 Select | N/A | Use BigQuery External Tables |
| S3 Batch Operations | GCS Batch | Different API |

---

## Authentication Translation

### Environment Variables

**S3:**
```bash
export AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
export AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
export AWS_DEFAULT_REGION=us-east-1
```

**GCS:**
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
export GCLOUD_PROJECT=your-project-id
```

### IAM Roles

**S3 IAM Role:**
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:GetObject",
      "s3:PutObject"
    ],
    "Resource": "arn:aws:s3:::bucket/*"
  }]
}
```

**GCS IAM Binding:**
```bash
# Grant storage.objectViewer (read)
gsutil iam ch user:alice@example.com:roles/storage.objectViewer gs://bucket

# Grant storage.objectCreator (write)
gsutil iam ch user:alice@example.com:roles/storage.objectCreator gs://bucket

# Grant storage.objectAdmin (read + write)
gsutil iam ch user:alice@example.com:roles/storage.objectAdmin gs://bucket
```

---

## Storage Class Translation

| Use Case | S3 Class | GCS Class | Min Duration | Retrieval Cost |
|----------|----------|-----------|--------------|----------------|
| Hot data, frequent access | Standard | Standard | None | Free (GCS) / $0.0004/1k (S3) |
| Warm data, monthly access | Standard-IA | Nearline | 30 days | $0.01/GB |
| Cold data, quarterly access | Glacier Flexible | Coldline | 90 days | $0.02/GB |
| Archive, yearly access | Glacier Deep | Archive | 365 days | $0.05/GB |

**Key difference:** GCS Standard has FREE read requests, making it better for analytics workloads.

---

## URL Format

**S3:**
```
s3://bucket-name/path/to/object
https://bucket-name.s3.amazonaws.com/path/to/object
https://s3.amazonaws.com/bucket-name/path/to/object
```

**GCS:**
```
gs://bucket-name/path/to/object
https://storage.googleapis.com/bucket-name/path/to/object
https://storage.cloud.google.com/bucket-name/path/to/object
```

---

## Common Patterns

### Pattern: Upload directory with parallelism

**S3:**
```bash
aws s3 cp ./data s3://bucket/data/ --recursive
```

**GCS:**
```bash
gsutil -m cp -r ./data gs://bucket/data/
```

### Pattern: Sync local to cloud (upload changes only)

**S3:**
```bash
aws s3 sync ./data s3://bucket/data/
```

**GCS:**
```bash
gsutil -m rsync -r ./data gs://bucket/data/
```

### Pattern: Grant read access to user

**S3:**
```bash
aws s3api put-bucket-policy --bucket bucket --policy file://policy.json
```

**GCS:**
```bash
gsutil iam ch user:alice@example.com:roles/storage.objectViewer gs://bucket
```

### Pattern: List only large files (>1GB)

**S3:**
```bash
aws s3 ls s3://bucket/ --recursive | awk '$3 > 1073741824'
```

**GCS:**
```bash
gsutil ls -l -r gs://bucket/ | awk '$1 > 1073741824'
```

### Pattern: Copy between buckets

**S3:**
```bash
aws s3 cp s3://source-bucket/file.txt s3://dest-bucket/file.txt
```

**GCS:**
```bash
gsutil cp gs://source-bucket/file.txt gs://dest-bucket/file.txt
```

---

## Configuration Files

### S3 (~/.aws/credentials)
```ini
[default]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

[profile prod]
aws_access_key_id = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
region = us-west-2
```

### GCS (service account key JSON)
```json
{
  "type": "service_account",
  "project_id": "your-project-id",
  "private_key_id": "key-id",
  "private_key": "-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n",
  "client_email": "service-account@project.iam.gserviceaccount.com",
  "client_id": "123456789",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token"
}
```

**Usage:**
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/key.json
```

---

## Pricing Comparison (Monthly, 1TB storage + 100M reads)

| Component | S3 (us-east-1) | GCS (us-central1) | Winner |
|-----------|----------------|-------------------|--------|
| Storage (1 TB Standard) | $23.00 | $20.00 | GCS |
| PUT requests (1M) | $5.00 | $5.00 | Tie |
| GET requests (100M) | $40.00 | **FREE** | GCS |
| Egress (100 GB) | $9.00 | $12.00 | S3 |
| **Total** | **$77.00** | **$37.00** | **GCS (-52%)** |

**Key takeaway:** GCS is significantly cheaper for analytics workloads with frequent reads.

---

## dtheinfra-Specific Setup

### Environment Setup

**For local development:**
```bash
# 1. Create GCS bucket
gsutil mb -l US-CENTRAL1 -c STANDARD gs://dtheinfra-lakehouse-dev

# 2. Enable versioning (required for Iceberg)
gsutil versioning set on gs://dtheinfra-lakehouse-dev

# 3. Create service account
gcloud iam service-accounts create iceberg-catalog \
    --description="Iceberg catalog GCS access" \
    --display-name="Iceberg Catalog"

# 4. Grant permissions
gsutil iam ch serviceAccount:iceberg-catalog@PROJECT.iam.gserviceaccount.com:roles/storage.admin \
    gs://dtheinfra-lakehouse-dev

# 5. Create key file
gcloud iam service-accounts keys create ~/gcs-keys/iceberg-sa-key.json \
    --iam-account=iceberg-catalog@PROJECT.iam.gserviceaccount.com

# 6. Configure Iceberg catalog
cd /Users/takudo/Documents/dtheinfra/infra/iceberg-catalog/dev
cp .env.example .env
# Edit .env:
#   GCP_SA_KEY_PATH=~/gcs-keys/iceberg-sa-key.json
#   GCS_WAREHOUSE_URI=gs://dtheinfra-lakehouse-dev/warehouse/
#   GCP_PROJECT_ID=your-project-id

# 7. Start catalog
./start-catalog.sh
```

### Verify Access

```bash
# Test gsutil access
export GOOGLE_APPLICATION_CREDENTIALS=~/gcs-keys/iceberg-sa-key.json
gsutil ls gs://dtheinfra-lakehouse-dev/

# Test Python SDK
python3 -c "
from google.cloud import storage
client = storage.Client()
bucket = client.bucket('dtheinfra-lakehouse-dev')
print(f'Bucket: {bucket.name}')
"

# Test Iceberg catalog
curl http://localhost:8181/v1/config
```

---

## Common Gotchas

### 1. No automatic parallelism
**S3:** `aws s3 cp` is parallel by default
**GCS:** Must use `gsutil -m` flag for parallel operations

### 2. Different recursive flag
**S3:** `--recursive`
**GCS:** `-r`

### 3. Free reads on Standard class
**S3:** Charges $0.0004 per 1,000 GET requests
**GCS:** FREE GET requests on Standard storage class

### 4. Service account vs IAM role
**S3:** Can use IAM roles (no keys) on EC2/ECS
**GCS:** Needs service account key file (or workload identity on GKE)

### 5. Bucket names are global
**S3:** Bucket names global across all AWS accounts
**GCS:** Bucket names global across all GCP projects (same as S3)

### 6. No bucket-level policies
**S3:** Can attach bucket policies directly
**GCS:** Uses IAM bindings (similar concept, different API)

### 7. Versioning is mandatory for Iceberg
**S3:** Optional, but recommended
**GCS:** Required for Iceberg ACID transactions

---

## Help & Resources

**Get help:**
```bash
# S3
aws s3 help
aws s3api help

# GCS
gsutil help
gsutil help cp
man gsutil
```

**Full documentation:**
- [GCS Architecture Overview](../architecture/google-cloud-storage.md)
- [GCS Operations Guide](./gcs-operations.md)
- [dtheinfra QUICKSTART](../../infra/QUICKSTART.md)
- [Official GCS Docs](https://cloud.google.com/storage/docs)

**Quick links:**
- [gsutil command reference](https://cloud.google.com/storage/docs/gsutil)
- [Python SDK reference](https://cloud.google.com/python/docs/reference/storage/latest)
- [GCS vs S3 comparison](https://cloud.google.com/free/docs/aws-azure-gcp-service-comparison)
