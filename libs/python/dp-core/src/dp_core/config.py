"""Configuration management for the data platform.

Supports hierarchical configuration loading with environment-based overrides:
1. Load base configs from config/base/*.yaml
2. Merge environment-specific config from config/environments/{env}.yaml
3. Apply environment variable overrides (DP_* prefix)
"""

from __future__ import annotations

import os
import re
from functools import lru_cache
from pathlib import Path
from typing import Any

import yaml
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    """Deep merge two dictionaries, with override taking precedence."""
    result = base.copy()
    for key, value in override.items():
        if key in result and isinstance(result[key], dict) and isinstance(value, dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = value
    return result


def resolve_env_vars(config: dict[str, Any]) -> dict[str, Any]:
    """Resolve ${VAR:default} patterns in config values."""
    pattern = r"\$\{([^}:]+)(?::([^}]*))?\}"

    def replacer(match: re.Match[str]) -> str:
        var_name = match.group(1)
        default = match.group(2) or ""
        return os.environ.get(var_name, default)

    def resolve_value(value: Any) -> Any:
        if isinstance(value, str):
            return re.sub(pattern, replacer, value)
        elif isinstance(value, dict):
            return {k: resolve_value(v) for k, v in value.items()}
        elif isinstance(value, list):
            return [resolve_value(item) for item in value]
        return value

    return resolve_value(config)


def load_yaml_config(
    config_dir: Path,
    environment: str | None = None,
    base_files: list[str] | None = None,
) -> dict[str, Any]:
    """Load configuration with hierarchical merging.

    1. Load all base configs
    2. Merge environment-specific config
    3. Resolve environment variables
    """
    environment = environment or os.environ.get("DP_ENVIRONMENT", "local")
    base_files = base_files or ["logging.yaml", "kafka.yaml", "spark.yaml", "iceberg.yaml"]

    merged_config: dict[str, Any] = {}
    base_dir = config_dir / "base"

    # Load base configs
    for filename in base_files:
        filepath = base_dir / filename
        if filepath.exists():
            with open(filepath) as f:
                file_config = yaml.safe_load(f) or {}
                merged_config = deep_merge(merged_config, file_config)

    # Load environment override
    env_file = config_dir / "environments" / f"{environment}.yaml"
    if env_file.exists():
        with open(env_file) as f:
            env_config = yaml.safe_load(f) or {}
            merged_config = deep_merge(merged_config, env_config)

    return resolve_env_vars(merged_config)


class KafkaConfig(BaseSettings):
    """Kafka connection configuration."""

    model_config = SettingsConfigDict(env_prefix="DP_KAFKA_")

    bootstrap_servers: str = "localhost:29092"
    schema_registry_url: str = "http://localhost:8081"
    security_protocol: str = "PLAINTEXT"

    # Consumer settings
    consumer_group_id: str | None = None
    auto_offset_reset: str = "earliest"
    enable_auto_commit: bool = False

    # Producer settings
    acks: str = "all"
    retries: int = 3
    compression_type: str = "lz4"


class S3Config(BaseSettings):
    """S3/MinIO configuration."""

    model_config = SettingsConfigDict(env_prefix="DP_S3_")

    endpoint_url: str | None = "http://localhost:9000"  # None for real AWS
    access_key_id: str | None = "minioadmin"
    secret_access_key: str | None = "minioadmin"
    bucket_bronze: str = "bronze"
    bucket_silver: str = "silver"
    bucket_gold: str = "gold"
    region: str = "us-east-1"


class IcebergConfig(BaseSettings):
    """Iceberg catalog configuration."""

    model_config = SettingsConfigDict(env_prefix="DP_ICEBERG_")

    catalog_type: str = "rest"  # rest, glue, hive
    catalog_uri: str = "http://localhost:8181"
    warehouse: str = "s3://warehouse/"


class SparkConfig(BaseSettings):
    """Spark configuration."""

    model_config = SettingsConfigDict(env_prefix="DP_SPARK_")

    master: str = "local[*]"
    app_name: str = "data-platform"
    executor_memory: str = "2g"
    driver_memory: str = "1g"


class DatabaseConfig(BaseSettings):
    """Database configuration."""

    model_config = SettingsConfigDict(env_prefix="DP_DB_")

    host: str = "localhost"
    port: int = 5432
    database: str = "dataplatform"
    username: str = "dataplatform"
    password: str = "dataplatform"

    @property
    def connection_string(self) -> str:
        """Build PostgreSQL connection string."""
        return f"postgresql://{self.username}:{self.password}@{self.host}:{self.port}/{self.database}"


class DataPlatformConfig(BaseSettings):
    """Main configuration aggregating all sub-configs."""

    model_config = SettingsConfigDict(
        env_prefix="DP_",
        env_nested_delimiter="__",
        extra="ignore",
    )

    environment: str = Field(default="local", description="Deployment environment")
    debug: bool = Field(default=False, description="Enable debug mode")
    project_name: str = Field(default="data-platform", description="Project name")

    kafka: KafkaConfig = Field(default_factory=KafkaConfig)
    s3: S3Config = Field(default_factory=S3Config)
    iceberg: IcebergConfig = Field(default_factory=IcebergConfig)
    spark: SparkConfig = Field(default_factory=SparkConfig)
    database: DatabaseConfig = Field(default_factory=DatabaseConfig)

    @classmethod
    def from_yaml(
        cls,
        config_dir: Path | str,
        environment: str | None = None,
    ) -> DataPlatformConfig:
        """Load configuration from YAML files with environment overrides."""
        if isinstance(config_dir, str):
            config_dir = Path(config_dir)

        yaml_config = load_yaml_config(config_dir, environment)
        return cls(**yaml_config)


@lru_cache
def get_config() -> DataPlatformConfig:
    """Get cached configuration instance.

    Looks for config directory in:
    1. DP_CONFIG_DIR environment variable
    2. ./config relative to current directory
    3. Falls back to environment variables only
    """
    config_dir_str = os.environ.get("DP_CONFIG_DIR")

    if config_dir_str:
        config_dir = Path(config_dir_str)
        if config_dir.exists():
            return DataPlatformConfig.from_yaml(config_dir)

    # Try relative config directory
    config_dir = Path("config")
    if config_dir.exists():
        return DataPlatformConfig.from_yaml(config_dir)

    # Fall back to environment variables only
    return DataPlatformConfig()
