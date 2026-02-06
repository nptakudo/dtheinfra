#!/usr/bin/env python3
"""
Seed sample Iceberg tables for the DataHub + Iceberg integration POC.

This script creates three sample tables in bronze, silver, and gold namespaces
using PyIceberg, then inserts sample data to demonstrate the integration.
"""

import os
import sys
from datetime import datetime, timezone
from typing import List

import pyarrow as pa
from pyiceberg.catalog import load_catalog
from pyiceberg.exceptions import NamespaceAlreadyExistsError, TableAlreadyExistsError
from pyiceberg.schema import Schema
from pyiceberg.types import (
    LongType,
    NestedField,
    StringType,
    TimestamptzType,
)


def get_catalog():
    """Load the Iceberg REST catalog."""
    catalog_uri = os.getenv("ICEBERG_CATALOG_URI", "http://localhost:8181")
    warehouse_uri = os.getenv("GCS_WAREHOUSE_URI", "gs://dtheinfra-lakehouse/warehouse/")

    print(f"📡 Connecting to Iceberg catalog at {catalog_uri}")
    print(f"🗄️  Warehouse location: {warehouse_uri}")

    catalog = load_catalog(
        "local_lakehouse",
        **{
            "type": "rest",
            "uri": catalog_uri,
            "warehouse": warehouse_uri,
        }
    )
    return catalog


def create_namespace(catalog, namespace: str):
    """Create a namespace if it doesn't exist."""
    try:
        catalog.create_namespace(namespace)
        print(f"✅ Created namespace: {namespace}")
    except NamespaceAlreadyExistsError:
        print(f"ℹ️  Namespace already exists: {namespace}")


def create_bronze_table(catalog):
    """Create bronze.raw_events table with sample data."""
    table_name = "bronze.raw_events"

    schema = Schema(
        NestedField(1, "user_id", StringType(), required=True),
        NestedField(2, "event_type", StringType(), required=True),
        NestedField(3, "timestamp", TimestamptzType(), required=True),
        NestedField(4, "payload", StringType(), required=False),
    )

    try:
        table = catalog.create_table(table_name, schema=schema)
        print(f"✅ Created table: {table_name}")
    except TableAlreadyExistsError:
        print(f"ℹ️  Table already exists: {table_name}")
        table = catalog.load_table(table_name)

    # Generate sample data
    num_rows = 100
    now = datetime.now(timezone.utc)

    data = {
        "user_id": [f"user_{i % 20:03d}" for i in range(num_rows)],
        "event_type": [
            ["login", "logout", "page_view", "click", "purchase"][i % 5]
            for i in range(num_rows)
        ],
        "timestamp": [now for _ in range(num_rows)],
        "payload": [f'{{"session_id": "sess_{i}"}}' for i in range(num_rows)],
    }

    arrow_table = pa.table(data, schema=table.schema().as_arrow())
    table.append(arrow_table)
    print(f"📝 Inserted {num_rows} rows into {table_name}")

    return table


def create_silver_table(catalog):
    """Create silver.cleaned_events table with sample data."""
    table_name = "silver.cleaned_events"

    schema = Schema(
        NestedField(1, "user_id", StringType(), required=True),
        NestedField(2, "event_type", StringType(), required=True),
        NestedField(3, "event_time", TimestamptzType(), required=True),
        NestedField(4, "processed_at", TimestamptzType(), required=True),
    )

    try:
        table = catalog.create_table(table_name, schema=schema)
        print(f"✅ Created table: {table_name}")
    except TableAlreadyExistsError:
        print(f"ℹ️  Table already exists: {table_name}")
        table = catalog.load_table(table_name)

    # Generate sample data
    num_rows = 100
    now = datetime.now(timezone.utc)

    data = {
        "user_id": [f"user_{i % 20:03d}" for i in range(num_rows)],
        "event_type": [
            ["login", "logout", "page_view", "click", "purchase"][i % 5]
            for i in range(num_rows)
        ],
        "event_time": [now for _ in range(num_rows)],
        "processed_at": [now for _ in range(num_rows)],
    }

    arrow_table = pa.table(data, schema=table.schema().as_arrow())
    table.append(arrow_table)
    print(f"📝 Inserted {num_rows} rows into {table_name}")

    return table


def create_gold_table(catalog):
    """Create gold.user_metrics table with sample data."""
    table_name = "gold.user_metrics"

    schema = Schema(
        NestedField(1, "user_id", StringType(), required=True),
        NestedField(2, "event_count", LongType(), required=True),
        NestedField(3, "last_event_time", TimestamptzType(), required=True),
    )

    try:
        table = catalog.create_table(table_name, schema=schema)
        print(f"✅ Created table: {table_name}")
    except TableAlreadyExistsError:
        print(f"ℹ️  Table already exists: {table_name}")
        table = catalog.load_table(table_name)

    # Generate sample data
    num_users = 20
    now = datetime.now(timezone.utc)

    data = {
        "user_id": [f"user_{i:03d}" for i in range(num_users)],
        "event_count": [(i + 1) * 5 for i in range(num_users)],
        "last_event_time": [now for _ in range(num_users)],
    }

    arrow_table = pa.table(data, schema=table.schema().as_arrow())
    table.append(arrow_table)
    print(f"📝 Inserted {num_users} rows into {table_name}")

    return table


def main():
    """Main execution function."""
    print("🚀 Starting Iceberg table seeding...")
    print()

    try:
        # Connect to catalog
        catalog = get_catalog()
        print()

        # Create namespaces
        print("📁 Creating namespaces...")
        for namespace in ["bronze", "silver", "gold"]:
            create_namespace(catalog, namespace)
        print()

        # Create and populate tables
        print("📊 Creating and populating tables...")
        create_bronze_table(catalog)
        create_silver_table(catalog)
        create_gold_table(catalog)
        print()

        # List all tables
        print("📋 Listing all tables in catalog:")
        for namespace in catalog.list_namespaces():
            namespace_name = ".".join(namespace)
            tables = catalog.list_tables(namespace_name)
            print(f"  {namespace_name}/")
            for table in tables:
                table_name = ".".join(table)
                table_obj = catalog.load_table(table_name)
                row_count = len(table_obj.scan().to_arrow())
                print(f"    - {table_name} ({row_count} rows)")
        print()

        print("✅ Seeding complete!")
        print()
        print("🔍 Next steps:")
        print("   1. Verify tables: curl http://localhost:8181/v1/namespaces")
        print("   2. Run DataHub ingestion: uv run datahub ingest -c infra/datahub/dev/recipes/iceberg_ingestion.yml")
        print("   3. Check DataHub UI: http://localhost:9002")

    except Exception as e:
        print(f"❌ Error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
