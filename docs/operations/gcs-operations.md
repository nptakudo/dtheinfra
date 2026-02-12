# GCS Operations Guide

**Last Updated:** 2026-02-06
**Audience:** Platform engineers and data engineers

## Table of Contents

1. [Setup Instructions](#setup-instructions)
2. [Common Operations](#common-operations)
3. [Service Account Management](#service-account-management)
4. [gsutil CLI Reference](#gsutil-cli-reference)
5. [Python SDK Usage](#python-sdk-usage)
6. [Monitoring and Debugging](#monitoring-and-debugging)
7. [Best Practices](#best-practices)
8. [Troubleshooting](#troubleshooting)

---

## Setup Instructions

### Prerequisites

- GCP account with billing enabled
- `gcloud` CLI installed ([installation guide](https://cloud.google.com/sdk/docs/install))
- Python 3.11+ for SDK usage

### 1. Install gcloud CLI

**macOS:**
```bash
brew install --cask google-cloud-sdk
```

**Linux:**
```bash
curl https://sdk.cloud.google.com | bash
exec -l $SHELL
```

**Verify installation:**
```bash
gcloud version
```

### 2. Authenticate

```bash
# Login with your Google account
gcloud auth login

# Set default project
gcloud config set project YOUR_PROJECT_ID

# Verify configuration
gcloud config list
```

### 3. Create GCS Bucket

**For dtheinfra development:**
```bash
# Create bucket in US-CENTRAL1 (low cost for dev)
gsutil mb -l US-CENTRAL1 -c STANDARD gs://dtheinfra-lakehouse-dev

# Enable versioning (required for Iceberg ACID)
gsutil versioning set on gs://dtheinfra-lakehouse-dev

# Enable uniform bucket-level access (recommended)
gsutil uniformbucketlevelaccess set on gs://dtheinfra-lakehouse-dev

# Verify bucket settings
gsutil ls -L -b gs://dtheinfra-lakehouse-dev
```

**For production:**
```bash
# Multi-region bucket for high availability
gsutil mb -l US -c STANDARD gs://dtheinfra-lakehouse-prod

# Enable versioning
gsutil versioning set on gs://dtheinfra-lakehouse-prod

# Enable uniform bucket-level access
gsutil uniformbucketlevelaccess set on gs://dtheinfra-lakehouse-prod

# Set retention policy (optional - prevent accidental deletion)
gsutil retention set 7d gs://dtheinfra-lakehouse-prod
```

### 4. Create Service Account

**For Iceberg catalog access:**
```bash
# Create service account
gcloud iam service-accounts create iceberg-catalog \
    --description="Service account for Iceberg catalog GCS access" \
    --display-name="Iceberg Catalog"

# Get service account email
SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:Iceberg Catalog" \
    --format="value(email)")

echo "Service Account: $SA_EMAIL"

# Grant Storage Admin role on bucket
gsutil iam ch serviceAccount:$SA_EMAIL:roles/storage.admin \
    gs://dtheinfra-lakehouse-dev

# Create and download key file
gcloud iam service-accounts keys create ~/gcs-keys/iceberg-catalog-key.json \
    --iam-account=$SA_EMAIL

echo "Key file created at: ~/gcs-keys/iceberg-catalog-key.json"
```

**Verify access:**
```bash
# Authenticate with service account
gcloud auth activate-service-account --key-file=~/gcs-keys/iceberg-catalog-key.json

# Test access
gsutil ls gs://dtheinfra-lakehouse-dev

# Switch back to user account
gcloud config set account YOUR_EMAIL@example.com
```

### 5. Configure Local Credentials

**Option 1: Application Default Credentials (ADC)**
```bash
# Set environment variable (recommended)
export GOOGLE_APPLICATION_CREDENTIALS=~/gcs-keys/iceberg-catalog-key.json

# Add to shell profile for persistence
echo 'export GOOGLE_APPLICATION_CREDENTIALS=~/gcs-keys/iceberg-catalog-key.json' >> ~/.bashrc
source ~/.bashrc
```

**Option 2: gcloud Application Default Credentials**
```bash
# Generate ADC file from your user credentials
gcloud auth application-default login

# ADC file location: ~/.config/gcloud/application_default_credentials.json
```

**For dtheinfra Iceberg catalog:**
```bash
# Edit infra/iceberg-catalog/dev/.env
cd /Users/takudo/Documents/dtheinfra/infra/iceberg-catalog/dev
cp .env.example .env

# Set in .env file:
# GCP_SA_KEY_PATH=~/gcs-keys/iceberg-catalog-key.json
# GCS_WAREHOUSE_URI=gs://dtheinfra-lakehouse-dev/warehouse/
# GCP_PROJECT_ID=your-project-id
```

### 6. Verify Setup

```bash
# List buckets
gsutil ls

# Upload test file
echo "Hello GCS" > /tmp/test.txt
gsutil cp /tmp/test.txt gs://dtheinfra-lakehouse-dev/test.txt

# Download test file
gsutil cp gs://dtheinfra-lakehouse-dev/test.txt /tmp/test-download.txt
cat /tmp/test-download.txt

# Clean up
gsutil rm gs://dtheinfra-lakehouse-dev/test.txt
```

---

## Common Operations

### Listing Objects

```bash
# List all buckets
gsutil ls

# List objects in bucket (top-level only)
gsutil ls gs://dtheinfra-lakehouse-dev/

# List objects recursively
gsutil ls -r gs://dtheinfra-lakehouse-dev/warehouse/

# List with details (size, timestamp, storage class)
gsutil ls -l gs://dtheinfra-lakehouse-dev/warehouse/bronze/

# List only directories (prefixes)
gsutil ls -d gs://dtheinfra-lakehouse-dev/warehouse/*/

# Count objects in a prefix
gsutil ls -r gs://dtheinfra-lakehouse-dev/warehouse/bronze/ | wc -l
```

### Uploading Files

```bash
# Upload single file
gsutil cp /path/to/file.txt gs://bucket/path/file.txt

# Upload with custom metadata
gsutil -h "Content-Type:application/json" \
       -h "x-goog-meta-owner:data-team" \
       cp data.json gs://bucket/data.json

# Upload directory recursively
gsutil -m cp -r /local/dir/* gs://bucket/path/

# Upload with parallelism (faster for many files)
gsutil -m cp -r /local/data/ gs://bucket/data/

# Upload with progress indicator
gsutil -o "GSUtil:parallel_process_count=4" \
       -o "GSUtil:parallel_thread_count=8" \
       -m cp -r /large/dataset/ gs://bucket/dataset/
```

### Downloading Files

```bash
# Download single file
gsutil cp gs://bucket/file.txt /local/path/file.txt

# Download directory
gsutil -m cp -r gs://bucket/data/ /local/data/

# Download specific files matching pattern
gsutil -m cp gs://bucket/data/*.parquet /local/data/

# Download only if local file is older
gsutil cp -n gs://bucket/data/* /local/data/
```

### Copying/Moving Objects

```bash
# Copy object within GCS
gsutil cp gs://bucket1/file.txt gs://bucket2/file.txt

# Copy directory
gsutil -m cp -r gs://bucket1/data/ gs://bucket2/data/

# Move object (copy + delete source)
gsutil mv gs://bucket/old-path/file.txt gs://bucket/new-path/file.txt

# Rename object
gsutil mv gs://bucket/old-name.txt gs://bucket/new-name.txt
```

### Deleting Objects

```bash
# Delete single object
gsutil rm gs://bucket/file.txt

# Delete multiple objects
gsutil -m rm gs://bucket/path/*.txt

# Delete directory recursively
gsutil -m rm -r gs://bucket/data/

# Delete with confirmation
gsutil rm -I gs://bucket/file.txt
```

### Syncing Directories

```bash
# Sync local to GCS (upload newer files only)
gsutil -m rsync -r /local/dir/ gs://bucket/dir/

# Sync GCS to local (download newer files only)
gsutil -m rsync -r gs://bucket/dir/ /local/dir/

# Sync with delete (remove files not in source)
gsutil -m rsync -r -d /local/dir/ gs://bucket/dir/

# Dry run (preview changes)
gsutil -m rsync -r -n /local/dir/ gs://bucket/dir/

# Sync excluding patterns
gsutil -m rsync -r -x '.*\.tmp$' /local/dir/ gs://bucket/dir/
```

### Viewing Object Metadata

```bash
# Get object metadata
gsutil stat gs://bucket/file.txt

# Get object size only
gsutil du gs://bucket/file.txt

# Get total size of directory
gsutil du -s gs://bucket/data/

# Get object checksum
gsutil hash gs://bucket/file.txt

# View object versions
gsutil ls -a gs://bucket/file.txt
```

### Setting Permissions

**Using IAM (recommended):**
```bash
# Grant user read access to bucket
gsutil iam ch user:alice@example.com:roles/storage.objectViewer gs://bucket

# Grant service account admin access
gsutil iam ch serviceAccount:sa@project.iam.gserviceaccount.com:roles/storage.admin gs://bucket

# View bucket IAM policy
gsutil iam get gs://bucket

# Remove permission
gsutil iam ch -d user:alice@example.com:roles/storage.objectViewer gs://bucket
```

**Using ACLs (legacy):**
```bash
# Make object publicly readable
gsutil acl ch -u AllUsers:R gs://bucket/public-file.txt

# Grant user write access
gsutil acl ch -u alice@example.com:W gs://bucket/file.txt

# View object ACL
gsutil acl get gs://bucket/file.txt
```

### Managing Lifecycle Policies

**Create lifecycle policy:**
```bash
# Create lifecycle.json
cat > /tmp/lifecycle.json <<EOF
{
  "lifecycle": {
    "rule": [
      {
        "action": {
          "type": "SetStorageClass",
          "storageClass": "NEARLINE"
        },
        "condition": {
          "age": 30,
          "matchesPrefix": ["warehouse/bronze/"]
        }
      },
      {
        "action": {
          "type": "Delete"
        },
        "condition": {
          "age": 365,
          "matchesPrefix": ["warehouse/bronze/tmp/"]
        }
      }
    ]
  }
}
EOF

# Apply lifecycle policy
gsutil lifecycle set /tmp/lifecycle.json gs://bucket

# View current policy
gsutil lifecycle get gs://bucket
```

**Common lifecycle patterns:**
```json
{
  "lifecycle": {
    "rule": [
      {
        "action": {"type": "SetStorageClass", "storageClass": "NEARLINE"},
        "condition": {"age": 30, "matchesPrefix": ["archive/"]}
      },
      {
        "action": {"type": "SetStorageClass", "storageClass": "COLDLINE"},
        "condition": {"age": 90, "matchesPrefix": ["archive/"]}
      },
      {
        "action": {"type": "Delete"},
        "condition": {"age": 365, "matchesPrefix": ["tmp/"]}
      },
      {
        "action": {"type": "Delete"},
        "condition": {"numNewerVersions": 3}
      }
    ]
  }
}
```

---

## Service Account Management

### Creating Service Accounts

```bash
# Create service account
gcloud iam service-accounts create SA_NAME \
    --description="DESCRIPTION" \
    --display-name="DISPLAY_NAME"

# Example: Create SA for data ingestion
gcloud iam service-accounts create data-ingestion \
    --description="Service account for Kafka to GCS ingestion" \
    --display-name="Data Ingestion SA"
```

### Granting Roles

**Recommended roles for GCS:**

| Role | Permissions | Use Case |
|------|-------------|----------|
| `roles/storage.objectViewer` | Read objects | Read-only access for analytics |
| `roles/storage.objectCreator` | Create objects | Write-only ingestion pipelines |
| `roles/storage.objectUser` | Read + create objects | Read/write for processing jobs |
| `roles/storage.objectAdmin` | Full object control | Iceberg catalog, data lifecycle |
| `roles/storage.admin` | Full bucket + object control | Admin operations, rare use |

**Grant role on specific bucket:**
```bash
# Storage Admin (for Iceberg catalog)
gsutil iam ch serviceAccount:SA_EMAIL:roles/storage.admin gs://bucket

# Object Viewer (read-only)
gsutil iam ch serviceAccount:SA_EMAIL:roles/storage.objectViewer gs://bucket

# Object User (read/write)
gsutil iam ch serviceAccount:SA_EMAIL:roles/storage.objectUser gs://bucket
```

**Grant role on project (all buckets):**
```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
    --member=serviceAccount:SA_EMAIL \
    --role=roles/storage.admin
```

### Managing Keys

```bash
# Create key
gcloud iam service-accounts keys create ~/keys/sa-key.json \
    --iam-account=SA_EMAIL

# List keys
gcloud iam service-accounts keys list \
    --iam-account=SA_EMAIL

# Delete key
gcloud iam service-accounts keys delete KEY_ID \
    --iam-account=SA_EMAIL

# Rotate key (create new, update config, delete old)
gcloud iam service-accounts keys create ~/keys/sa-key-new.json \
    --iam-account=SA_EMAIL
# Update application config to use new key
# Delete old key after verification
```

### Security Best Practices

```bash
# 1. Use least privilege
# Grant only the minimum role required

# 2. Rotate keys regularly (every 90 days)
# Set calendar reminder to rotate keys

# 3. Use workload identity in GKE (avoids key files)
gcloud iam service-accounts add-iam-policy-binding SA_EMAIL \
    --role=roles/iam.workloadIdentityUser \
    --member="serviceAccount:PROJECT_ID.svc.id.goog[NAMESPACE/KSA]"

# 4. Never commit keys to git
echo "*.json" >> .gitignore  # Add key files to .gitignore

# 5. Use Secret Manager for production
gcloud secrets create iceberg-sa-key --data-file=~/keys/sa-key.json
```

---

## gsutil CLI Reference

### Configuration

```bash
# Initialize gsutil configuration
gcloud init

# Configure gsutil settings
gsutil config

# View current configuration
gsutil version -l

# Set parallel upload/download threads
gsutil -o "GSUtil:parallel_thread_count=8" cp ...

# Set parallel processes
gsutil -o "GSUtil:parallel_process_count=4" cp ...

# Disable multithreading (for debugging)
gsutil -m cp ... # -m flag enables multithreading
```

### Performance Tuning

**Optimize for large files:**
```bash
# Enable parallel composite uploads (files > 150 MB)
gsutil -o GSUtil:parallel_composite_upload_threshold=150M cp large-file.zip gs://bucket/

# Set slice size for composite uploads
gsutil -o GSUtil:parallel_composite_upload_component_size=50M cp huge-file.tar.gz gs://bucket/
```

**Optimize for many small files:**
```bash
# Use multithreading
gsutil -m cp -r /data/ gs://bucket/data/

# Increase thread count
gsutil -o "GSUtil:parallel_thread_count=16" \
       -o "GSUtil:parallel_process_count=8" \
       -m cp -r /data/ gs://bucket/data/
```

### Useful Flags

| Flag | Description | Example |
|------|-------------|---------|
| `-m` | Parallel operations | `gsutil -m cp *.txt gs://bucket/` |
| `-r` | Recursive | `gsutil -m cp -r /dir/ gs://bucket/` |
| `-n` | No-clobber (skip existing) | `gsutil cp -n gs://bucket/* /local/` |
| `-d` | Delete extra files (rsync) | `gsutil rsync -d -r /dir/ gs://bucket/` |
| `-a` | Include old versions | `gsutil ls -a gs://bucket/file.txt` |
| `-l` | Long listing (size, time) | `gsutil ls -l gs://bucket/` |
| `-L` | Long listing for buckets | `gsutil ls -L -b gs://bucket` |
| `-h` | Set metadata | `gsutil -h "Content-Type:text/html" cp ...` |
| `-o` | Set config option | `gsutil -o "GSUtil:parallel_thread_count=8" ...` |

---

## Python SDK Usage

### Installation

```bash
# Install google-cloud-storage
pip install google-cloud-storage

# Or with uv (recommended for dtheinfra)
uv add google-cloud-storage
```

### Basic Operations

**Initialize client:**
```python
from google.cloud import storage

# Using ADC (GOOGLE_APPLICATION_CREDENTIALS env var)
client = storage.Client()

# Using explicit service account key
client = storage.Client.from_service_account_json(
    '/path/to/service-account-key.json'
)

# Using explicit project ID
client = storage.Client(project='your-project-id')
```

**List buckets:**
```python
# List all buckets
buckets = client.list_buckets()
for bucket in buckets:
    print(bucket.name)

# Get specific bucket
bucket = client.bucket('dtheinfra-lakehouse-dev')
print(f"Bucket: {bucket.name}, Location: {bucket.location}")
```

**List objects:**
```python
# List all objects in bucket
blobs = bucket.list_blobs()
for blob in blobs:
    print(f"{blob.name} ({blob.size} bytes)")

# List objects with prefix
blobs = bucket.list_blobs(prefix='warehouse/bronze/')
for blob in blobs:
    print(blob.name)

# List with delimiter (directories only)
blobs = bucket.list_blobs(prefix='warehouse/', delimiter='/')
for prefix in blobs.prefixes:
    print(f"Directory: {prefix}")
```

**Upload files:**
```python
# Upload from local file
blob = bucket.blob('warehouse/test.txt')
blob.upload_from_filename('/local/file.txt')
print(f"Uploaded to gs://{bucket.name}/{blob.name}")

# Upload from string
blob = bucket.blob('warehouse/data.json')
blob.upload_from_string('{"key": "value"}', content_type='application/json')

# Upload with metadata
blob = bucket.blob('warehouse/data.parquet')
blob.metadata = {'owner': 'data-team', 'version': '1.0'}
blob.upload_from_filename('/local/data.parquet')

# Upload with progress callback
def upload_progress(bytes_uploaded):
    print(f"Uploaded {bytes_uploaded} bytes")

blob.upload_from_filename('/local/large-file.zip',
                          callback=upload_progress)
```

**Download files:**
```python
# Download to local file
blob = bucket.blob('warehouse/data.txt')
blob.download_to_filename('/local/data.txt')

# Download as bytes
data_bytes = blob.download_as_bytes()

# Download as string
data_string = blob.download_as_text()

# Download as JSON
import json
blob = bucket.blob('warehouse/config.json')
config = json.loads(blob.download_as_text())
```

**Copy/move objects:**
```python
# Copy object
source_blob = bucket.blob('old-path/file.txt')
dest_blob = bucket.copy_blob(source_blob, bucket, 'new-path/file.txt')

# Move object (copy + delete)
source_blob = bucket.blob('old-path/file.txt')
dest_blob = bucket.copy_blob(source_blob, bucket, 'new-path/file.txt')
source_blob.delete()
```

**Delete objects:**
```python
# Delete single object
blob = bucket.blob('warehouse/tmp/file.txt')
blob.delete()

# Delete multiple objects
blobs_to_delete = bucket.list_blobs(prefix='warehouse/tmp/')
for blob in blobs_to_delete:
    blob.delete()
    print(f"Deleted {blob.name}")

# Delete with error handling
try:
    blob.delete()
except google.api_core.exceptions.NotFound:
    print("Object does not exist")
```

**Get object metadata:**
```python
blob = bucket.blob('warehouse/data.parquet')
blob.reload()  # Fetch latest metadata

print(f"Name: {blob.name}")
print(f"Size: {blob.size} bytes")
print(f"Content-Type: {blob.content_type}")
print(f"Created: {blob.time_created}")
print(f"Updated: {blob.updated}")
print(f"MD5: {blob.md5_hash}")
print(f"Storage Class: {blob.storage_class}")
print(f"Custom Metadata: {blob.metadata}")
```

### Advanced Usage

**Signed URLs:**
```python
from datetime import timedelta

# Generate signed URL for download (1 hour)
blob = bucket.blob('warehouse/data.csv')
url = blob.generate_signed_url(
    version='v4',
    expiration=timedelta(hours=1),
    method='GET'
)
print(f"Download URL: {url}")

# Generate signed URL for upload
url = blob.generate_signed_url(
    version='v4',
    expiration=timedelta(minutes=15),
    method='PUT',
    content_type='application/octet-stream'
)
print(f"Upload URL: {url}")
```

**Batch operations:**
```python
# Upload multiple files in parallel
from concurrent.futures import ThreadPoolExecutor

def upload_file(local_path, gcs_path):
    blob = bucket.blob(gcs_path)
    blob.upload_from_filename(local_path)
    return gcs_path

files_to_upload = [
    ('/local/file1.txt', 'warehouse/file1.txt'),
    ('/local/file2.txt', 'warehouse/file2.txt'),
    ('/local/file3.txt', 'warehouse/file3.txt'),
]

with ThreadPoolExecutor(max_workers=4) as executor:
    futures = [executor.submit(upload_file, local, gcs)
               for local, gcs in files_to_upload]
    for future in futures:
        print(f"Uploaded {future.result()}")
```

**Versioning:**
```python
# Enable versioning on bucket
bucket.versioning_enabled = True
bucket.patch()

# List all versions of an object
blobs = bucket.list_blobs(prefix='warehouse/data.txt', versions=True)
for blob in blobs:
    print(f"Version: {blob.generation}, Updated: {blob.updated}")

# Download specific version
blob = bucket.blob('warehouse/data.txt', generation=1234567890)
blob.download_to_filename('/local/data-v1.txt')

# Delete specific version
blob.delete()
```

**Lifecycle management:**
```python
# Set lifecycle policy
from google.cloud.storage import LifecycleRuleDelete, LifecycleRuleSetStorageClass

bucket.add_lifecycle_delete_rule(age=365, matches_prefix=['tmp/'])
bucket.add_lifecycle_set_storage_class_rule(
    storage_class='NEARLINE',
    age=30,
    matches_prefix=['archive/']
)
bucket.patch()

# View lifecycle rules
for rule in bucket.lifecycle_rules:
    print(f"Action: {rule['action']}, Condition: {rule['condition']}")

# Clear lifecycle rules
bucket.clear_lifecyle_rules()
bucket.patch()
```

---

## Monitoring and Debugging

### Viewing Logs

**gsutil logging:**
```bash
# Enable debug logging
gsutil -D cp gs://bucket/file.txt /local/

# Save debug output to file
gsutil -D cp gs://bucket/file.txt /local/ 2> debug.log

# Enable HTTP trace
gsutil -d cp gs://bucket/file.txt /local/
```

**Cloud Logging:**
```bash
# View GCS logs via gcloud
gcloud logging read "resource.type=gcs_bucket" --limit 50

# View logs for specific bucket
gcloud logging read "resource.type=gcs_bucket AND resource.labels.bucket_name=dtheinfra-lakehouse-dev" \
    --limit 50 --format=json

# View access logs
gcloud logging read "protoPayload.serviceName=storage.googleapis.com" \
    --limit 50
```

### Performance Monitoring

**Check transfer speeds:**
```bash
# Upload with timing
time gsutil -m cp -r /data/ gs://bucket/data/

# Download with timing
time gsutil -m cp -r gs://bucket/data/ /local/data/
```

**Monitor storage usage:**
```bash
# Get total bucket size
gsutil du -s gs://bucket/

# Get size by prefix
gsutil du -s gs://bucket/warehouse/bronze/
gsutil du -s gs://bucket/warehouse/silver/
gsutil du -s gs://bucket/warehouse/gold/

# Get object count
gsutil ls -r gs://bucket/ | wc -l
```

**View Cloud Monitoring metrics:**
```bash
# Install gcloud monitoring component
gcloud components install alpha

# Query storage metrics
gcloud alpha monitoring read 'storage.googleapis.com/storage/total_bytes' \
    --filter='resource.labels.bucket_name="dtheinfra-lakehouse-dev"'
```

### Debugging Connection Issues

**Test connectivity:**
```bash
# Test DNS resolution
nslookup storage.googleapis.com

# Test HTTPS connection
curl -I https://storage.googleapis.com

# Test gsutil
gsutil ls gs://bucket/ -d
```

**Check credentials:**
```bash
# Verify active account
gcloud auth list

# Verify project
gcloud config get-value project

# Test service account key
gcloud auth activate-service-account --key-file=/path/to/key.json
gsutil ls gs://bucket/
```

**Validate IAM permissions:**
```bash
# Check bucket IAM policy
gsutil iam get gs://bucket/

# Check service account permissions
gcloud projects get-iam-policy PROJECT_ID \
    --flatten="bindings[].members" \
    --filter="bindings.members:serviceAccount:SA_EMAIL"

# Test specific permission
gcloud storage buckets list --impersonate-service-account=SA_EMAIL
```

---

## Best Practices

### Bucket Naming Conventions

```bash
# Pattern: {org}-{purpose}-{env}
dtheinfra-lakehouse-dev
dtheinfra-lakehouse-staging
dtheinfra-lakehouse-prod

# Pattern: {org}-{layer}-{env}
dtheinfra-bronze-prod
dtheinfra-silver-prod
dtheinfra-gold-prod

# Pattern: {org}-{function}-{region}
dtheinfra-logs-us-central1
dtheinfra-backups-us
```

### Object Naming Conventions

```bash
# Use forward slashes for hierarchy
warehouse/bronze/raw_events/year=2026/month=02/day=06/data.parquet

# Use lowercase
warehouse/bronze/raw_events/  # Good
warehouse/Bronze/Raw_Events/  # Avoid

# Use hyphens for compound names
user-events-202602.parquet  # Good
user_events_202602.parquet  # Also OK
UserEvents202602.parquet    # Avoid

# Include partition keys in path (Iceberg convention)
warehouse/bronze/events/year=2026/month=02/00000-0-abc123.parquet
```

### Security Best Practices

**1. Use IAM over ACLs:**
```bash
# Enable uniform bucket-level access (disables ACLs)
gsutil uniformbucketlevelaccess set on gs://bucket
```

**2. Principle of least privilege:**
```bash
# Grant minimum required role
gsutil iam ch serviceAccount:SA:roles/storage.objectViewer gs://bucket  # Read-only
gsutil iam ch serviceAccount:SA:roles/storage.objectCreator gs://bucket  # Write-only
```

**3. Rotate service account keys:**
```bash
# Create key rotation script
#!/bin/bash
SA_EMAIL="iceberg-catalog@project.iam.gserviceaccount.com"
KEY_FILE="~/keys/iceberg-sa-key.json"
OLD_KEY_ID=$(gcloud iam service-accounts keys list --iam-account=$SA_EMAIL --format="value(name)" | head -n1)

# Create new key
gcloud iam service-accounts keys create $KEY_FILE --iam-account=$SA_EMAIL

# Update application config
# ... (restart services with new key)

# Delete old key after verification
gcloud iam service-accounts keys delete $OLD_KEY_ID --iam-account=$SA_EMAIL --quiet
```

**4. Use VPC Service Controls (production):**
```bash
# Create service perimeter to restrict GCS access
gcloud access-context-manager perimeters create dtheinfra-perimeter \
    --title="dtheinfra GCS Perimeter" \
    --resources=projects/PROJECT_NUMBER \
    --restricted-services=storage.googleapis.com
```

**5. Enable data access logs:**
```bash
# Enable data access logging (Cloud Console or API)
# Note: generates significant log volume
```

### Cost Optimization

**1. Use appropriate storage class:**
```bash
# Standard: Active data (bronze/silver/gold layers)
# Nearline: Monthly access (archived partitions)
# Coldline: Quarterly access (compliance data)
# Archive: Yearly access (legal hold)

# Set storage class on upload
gsutil -h "x-goog-storage-class:NEARLINE" cp file.txt gs://bucket/archive/
```

**2. Implement lifecycle policies:**
```bash
# Transition bronze data to Nearline after 30 days
# Delete temp data after 7 days
gsutil lifecycle set lifecycle.json gs://bucket
```

**3. Use regional buckets for single-region workloads:**
```bash
# Regional bucket (cheaper than multi-region)
gsutil mb -l US-CENTRAL1 -c STANDARD gs://dtheinfra-dev
```

**4. Enable compression for uploads:**
```bash
# Compress before upload
tar -czf data.tar.gz /data/
gsutil cp data.tar.gz gs://bucket/

# Or use gsutil compression
gsutil -h "Content-Encoding:gzip" cp data.json.gz gs://bucket/data.json
```

**5. Monitor storage usage:**
```bash
# Set up billing alerts in Cloud Console
# Monitor per-bucket usage
gsutil du -sh gs://bucket/
```

### Performance Optimization

**1. Use parallel uploads/downloads:**
```bash
# Enable multithreading
gsutil -m cp -r /data/ gs://bucket/data/

# Tune thread count based on file sizes
gsutil -o "GSUtil:parallel_thread_count=16" -m cp -r /data/ gs://bucket/
```

**2. Use composite uploads for large files:**
```bash
# Set threshold for composite uploads
gsutil -o GSUtil:parallel_composite_upload_threshold=150M cp large.zip gs://bucket/
```

**3. Colocate compute and storage:**
```bash
# Use bucket in same region as compute
# Good: GCE in us-central1, bucket in us-central1
# Bad: GCE in us-central1, bucket in europe-west1
```

**4. Use signed URLs for direct access:**
```python
# Avoid proxying through application
# Generate signed URL and return to client for direct download
url = blob.generate_signed_url(version='v4', expiration=3600, method='GET')
```

**5. Cache frequently accessed objects:**
```bash
# Use Cloud CDN for public objects
# Or implement application-level caching
```

---

## Troubleshooting

### Common Issues

#### Issue: "Access Denied" when listing bucket

**Cause:** Service account lacks IAM permissions.

**Solution:**
```bash
# Check current permissions
gsutil iam get gs://bucket/

# Grant storage.objectViewer role
gsutil iam ch serviceAccount:SA_EMAIL:roles/storage.objectViewer gs://bucket/

# Verify access
gsutil ls gs://bucket/
```

#### Issue: "Bucket does not exist"

**Cause:** Typo in bucket name, or bucket in different project.

**Solution:**
```bash
# List all buckets in project
gsutil ls

# Verify project
gcloud config get-value project

# Switch project if needed
gcloud config set project CORRECT_PROJECT_ID
```

#### Issue: "403 Forbidden" when uploading

**Cause:** Service account has objectViewer (read-only) but needs objectCreator.

**Solution:**
```bash
# Grant objectCreator role (write access)
gsutil iam ch serviceAccount:SA_EMAIL:roles/storage.objectCreator gs://bucket/

# Or grant objectAdmin (read + write)
gsutil iam ch serviceAccount:SA_EMAIL:roles/storage.objectAdmin gs://bucket/
```

#### Issue: Slow upload/download speeds

**Cause:** Single-threaded operations, network throttling.

**Solution:**
```bash
# Enable parallel uploads
gsutil -m cp -r /data/ gs://bucket/

# Increase thread count
gsutil -o "GSUtil:parallel_thread_count=16" \
       -o "GSUtil:parallel_process_count=4" \
       -m cp -r /data/ gs://bucket/

# Use composite uploads for large files
gsutil -o GSUtil:parallel_composite_upload_threshold=150M cp huge.zip gs://bucket/
```

#### Issue: "Invalid credentials"

**Cause:** Service account key expired, invalid key file, or wrong environment variable.

**Solution:**
```bash
# Verify GOOGLE_APPLICATION_CREDENTIALS
echo $GOOGLE_APPLICATION_CREDENTIALS

# Verify key file exists
ls -la $GOOGLE_APPLICATION_CREDENTIALS

# Verify key file is valid JSON
cat $GOOGLE_APPLICATION_CREDENTIALS | jq .

# Test authentication
gcloud auth activate-service-account --key-file=$GOOGLE_APPLICATION_CREDENTIALS
gsutil ls gs://bucket/
```

#### Issue: Lakekeeper can't connect to GCS

**Cause:** Invalid GCS credentials, bucket doesn't exist, or wrong warehouse URI.

**Solution:**
```bash
# Check Lakekeeper logs
cd /Users/takudo/Documents/dtheinfra/infra/iceberg-catalog/dev
docker compose logs lakekeeper

# Verify .env configuration
cat .env

# Verify bucket exists
gsutil ls gs://YOUR_BUCKET_NAME/

# Test credentials manually
export GOOGLE_APPLICATION_CREDENTIALS=$(grep GCP_SA_KEY_PATH .env | cut -d= -f2)
gsutil ls gs://YOUR_BUCKET_NAME/
```

#### Issue: "Object versioning is not enabled"

**Cause:** Iceberg requires versioning for ACID transactions.

**Solution:**
```bash
# Enable versioning
gsutil versioning set on gs://bucket/

# Verify versioning is enabled
gsutil versioning get gs://bucket/
```

#### Issue: DataHub can't ingest Iceberg tables

**Cause:** Catalog unreachable, or GCS credentials not mounted.

**Solution:**
```bash
# Verify Iceberg catalog is running
curl http://localhost:8181/v1/config

# Verify tables exist
curl http://localhost:8181/v1/namespaces

# Check DataHub can reach catalog
docker exec datahub-gms curl http://lakekeeper:8181/v1/config

# Verify both containers on same network
docker network inspect dtheinfra-network
```

### Debugging Checklist

When encountering GCS issues, check:

- [ ] Bucket name is correct (case-sensitive, no typos)
- [ ] Bucket exists in the correct project
- [ ] Service account has appropriate IAM role
- [ ] Service account key file exists and is valid JSON
- [ ] `GOOGLE_APPLICATION_CREDENTIALS` environment variable is set
- [ ] Versioning is enabled (required for Iceberg)
- [ ] Uniform bucket-level access is enabled (recommended)
- [ ] No lifecycle policies deleting objects unexpectedly
- [ ] Network connectivity to `storage.googleapis.com`
- [ ] Billing is enabled on GCP project

---

## Next Steps

- [GCS Architecture Overview](../architecture/google-cloud-storage.md)
- [Iceberg Catalog Setup](../../infra/iceberg-catalog/README.md)
- [QUICKSTART Guide](../../infra/QUICKSTART.md)
- [DataHub Integration](../../infra/datahub/README.md)

---

## References

- [GCS Documentation](https://cloud.google.com/storage/docs)
- [gsutil Tool](https://cloud.google.com/storage/docs/gsutil)
- [google-cloud-storage Python SDK](https://cloud.google.com/python/docs/reference/storage/latest)
- [GCS Best Practices](https://cloud.google.com/storage/docs/best-practices)
- [IAM for GCS](https://cloud.google.com/storage/docs/access-control/iam)
