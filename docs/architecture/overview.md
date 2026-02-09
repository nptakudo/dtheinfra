# Architecture Documentation

This directory contains architecture documentation for the dtheinfra platform.

## Overview Documents

### Storage & Data Infrastructure

- [Google Cloud Storage (GCS) Overview](./google-cloud-storage.md) - Comprehensive guide to GCS concepts, GCS vs S3 comparison, and dtheinfra usage
- [GCS Visual Guide](./gcs-visual-guide.md) - Diagrams and visual representations of GCS architecture
- [Architecture Decision Records (ADRs)](./adr/) - Key design decisions

## Quick Links

### For S3 Users
If you're familiar with AWS S3 and new to GCS, start here:
1. [GCS Overview - S3 Comparison Section](./google-cloud-storage.md#gcs-vs-s3-comparison)
2. [GCS Quick Reference for S3 Users](../operations/gcs-quick-reference.md)
3. [GCS Operations Guide](../operations/gcs-operations.md)

### For New Team Members
If you're new to the dtheinfra platform:
1. [Getting Started Guide](../development/getting-started.md)
2. [GCS Visual Guide](./gcs-visual-guide.md) - Understand storage architecture
3. [GCS Overview](./google-cloud-storage.md) - Deep dive into concepts
4. [Iceberg Catalog Setup](../../infra/iceberg-catalog/README.md)

### For Operations
If you need to set up or manage GCS:
1. [GCS Operations Guide](../operations/gcs-operations.md) - Complete setup instructions
2. [GCS Quick Reference](../operations/gcs-quick-reference.md) - Command cheat sheet
3. [QUICKSTART Guide](../../infra/QUICKSTART.md) - End-to-end setup

## Architecture Decision Records (ADRs)

Key architectural decisions are documented in ADRs:

- [ADR 0001: Use Apache Iceberg as Table Format](./adr/0001-use-iceberg-as-table-format.md)
- [ADR 0002: Use Google Cloud Storage for Object Storage](./adr/0002-use-gcs-for-storage.md)

## Documentation Structure

```
docs/
├── architecture/           # High-level design and concepts
│   ├── google-cloud-storage.md       # GCS overview and concepts
│   ├── gcs-visual-guide.md           # Visual diagrams
│   └── adr/                          # Architecture Decision Records
│       ├── 0001-use-iceberg-as-table-format.md
│       └── 0002-use-gcs-for-storage.md
├── operations/             # Operational guides and how-tos
│   ├── gcs-operations.md            # GCS setup and CLI reference
│   └── gcs-quick-reference.md       # S3 to GCS command translation
└── development/            # Developer setup guides
    └── getting-started.md           # Initial setup for developers
```

## Contributing to Documentation

When adding new architecture documentation:

1. Place conceptual/design docs in `docs/architecture/`
2. Place operational/how-to docs in `docs/operations/`
3. Use Mermaid diagrams for all visual concepts
4. Include code examples with full commands
5. Cross-reference related documentation
6. Update this README with new documents

## Related Documentation

- [Iceberg Catalog](../../infra/iceberg-catalog/README.md) - Lakekeeper setup with GCS
- [DataHub](../../infra/datahub/README.md) - Metadata catalog integration
- [QUICKSTART](../../infra/QUICKSTART.md) - Complete integration guide
- [Component Pattern](../../infra/COMPONENT_PATTERN.md) - Infrastructure component standards
