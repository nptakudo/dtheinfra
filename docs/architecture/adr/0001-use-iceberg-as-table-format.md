# ADR 0001: Use Apache Iceberg as Table Format

## Status

Accepted

## Context

We need to choose a table format for our lakehouse architecture that supports:
- ACID transactions
- Schema evolution
- Time travel / versioning
- Efficient query performance
- Integration with Spark, Flink, and other engines
- AWS ecosystem compatibility

The main contenders are:
- Apache Iceberg
- Delta Lake
- Apache Hudi

## Decision

We will use **Apache Iceberg** as our table format.

## Rationale

1. **Engine Agnostic**: Iceberg is designed to work with multiple engines (Spark, Flink, Trino, Dremio) without vendor lock-in.

2. **AWS Integration**: Native integration with AWS Glue Catalog, S3, and EMR Serverless.

3. **Advanced Features**:
   - Hidden partitioning (no need to specify partition columns in queries)
   - Partition evolution without rewriting data
   - Time travel with snapshot isolation
   - Efficient metadata management with manifest files

4. **Community & Adoption**: Strong community support, adopted by major tech companies (Netflix, Apple, LinkedIn).

5. **Performance**: Efficient predicate pushdown, file-level statistics, and manifest caching.

## Consequences

### Positive
- Clean separation between storage and compute
- Easy schema evolution without data rewrites
- Efficient time travel for debugging and auditing
- Works with both batch (Spark) and streaming (Flink)

### Negative
- Need to manage Iceberg catalog (REST catalog or Glue)
- Learning curve for team members unfamiliar with lakehouse concepts
- Additional operational overhead for table maintenance (compaction, snapshot expiration)

### Mitigation
- Use AWS Glue as catalog for production (managed service)
- Use REST catalog for local development
- Automate table maintenance via Airflow DAGs
