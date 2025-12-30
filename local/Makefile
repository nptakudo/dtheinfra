.PHONY: help up up-core down down-clean logs ps shell-kafka shell-spark shell-flink shell-postgres create-topics

# Default target
help:
	@echo "Local Development Environment Commands"
	@echo ""
	@echo "Start/Stop:"
	@echo "  up          - Start all services (full stack)"
	@echo "  up-core     - Start core services only (Kafka, MinIO, Postgres)"
	@echo "  down        - Stop all services"
	@echo "  down-clean  - Stop all services and remove volumes"
	@echo ""
	@echo "Monitoring:"
	@echo "  logs        - Follow logs from all services"
	@echo "  ps          - Show running services"
	@echo ""
	@echo "Shell Access:"
	@echo "  shell-kafka    - Open shell in Kafka container"
	@echo "  shell-spark    - Open Spark shell with Iceberg"
	@echo "  shell-flink    - Open Flink SQL client"
	@echo "  shell-postgres - Open PostgreSQL shell"
	@echo ""
	@echo "Setup:"
	@echo "  create-topics  - Create default Kafka topics"

# Start all services
up:
	docker-compose up -d

# Start core services only (faster startup)
up-core:
	docker-compose -f docker-compose.core.yml up -d

# Stop all services
down:
	docker-compose down
	docker-compose -f docker-compose.core.yml down 2>/dev/null || true

# Stop and remove volumes
down-clean:
	docker-compose down -v
	docker-compose -f docker-compose.core.yml down -v 2>/dev/null || true

# Follow logs
logs:
	docker-compose logs -f

# Show running services
ps:
	docker-compose ps

# Kafka shell
shell-kafka:
	docker exec -it dp-kafka bash

# Spark shell with Iceberg support
shell-spark:
	docker exec -it dp-spark-master spark-shell \
		--packages org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.4.3,org.apache.hadoop:hadoop-aws:3.3.4 \
		--conf spark.sql.catalog.local=org.apache.iceberg.spark.SparkCatalog \
		--conf spark.sql.catalog.local.type=rest \
		--conf spark.sql.catalog.local.uri=http://iceberg-rest:8181 \
		--conf spark.sql.catalog.local.warehouse=s3://warehouse/ \
		--conf spark.hadoop.fs.s3a.endpoint=http://minio:9000 \
		--conf spark.hadoop.fs.s3a.access.key=minioadmin \
		--conf spark.hadoop.fs.s3a.secret.key=minioadmin \
		--conf spark.hadoop.fs.s3a.path.style.access=true

# Flink SQL client
shell-flink:
	docker exec -it dp-flink-jobmanager ./bin/sql-client.sh

# PostgreSQL shell
shell-postgres:
	docker exec -it dp-postgres psql -U dataplatform

# Create Kafka topics
create-topics:
	./init-scripts/kafka/create-topics.sh
