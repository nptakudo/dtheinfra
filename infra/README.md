# infra

Infrastructure as Code (IaC) and configuration for the data platform's cloud resources and services.

- Contains **Terraform modules** organized by domain (compute, networking, storage, governance, orchestration, observability) for provisioning cloud infrastructure(AWS, GCP).
- Defines **environment-specific configurations** (dev, staging, prod) and global shared resources in the `terraform/` directory.
- Houses **component directories** (airflow, kafka, spark, flink, etc.) for service-specific deployment configs, manifests, and documentation.
- Provides the foundation for deploying the Lambda architecture: streaming pipeline (Kafka, Flink), batch processing (Spark), orchestration (Airflow), and Lakehouse storage (S3 + Iceberg).
- Consumed by deployment workflows and local development; keeps infrastructure definitions version-controlled and reproducible.
