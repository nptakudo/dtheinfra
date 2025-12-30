"""Tests for configuration management."""

import os
from pathlib import Path
from tempfile import TemporaryDirectory

import pytest
import yaml

from dp_core.config import (
    DataPlatformConfig,
    KafkaConfig,
    S3Config,
    deep_merge,
    load_yaml_config,
    resolve_env_vars,
)


class TestDeepMerge:
    """Tests for deep_merge function."""

    def test_simple_merge(self) -> None:
        base = {"a": 1, "b": 2}
        override = {"b": 3, "c": 4}
        result = deep_merge(base, override)
        assert result == {"a": 1, "b": 3, "c": 4}

    def test_nested_merge(self) -> None:
        base = {"a": {"x": 1, "y": 2}, "b": 3}
        override = {"a": {"y": 10, "z": 20}}
        result = deep_merge(base, override)
        assert result == {"a": {"x": 1, "y": 10, "z": 20}, "b": 3}

    def test_override_dict_with_value(self) -> None:
        base = {"a": {"x": 1}}
        override = {"a": "simple"}
        result = deep_merge(base, override)
        assert result == {"a": "simple"}


class TestResolveEnvVars:
    """Tests for environment variable resolution."""

    def test_resolve_existing_var(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("TEST_VAR", "test_value")
        config = {"key": "${TEST_VAR}"}
        result = resolve_env_vars(config)
        assert result == {"key": "test_value"}

    def test_resolve_with_default(self) -> None:
        config = {"key": "${NONEXISTENT_VAR:default_value}"}
        result = resolve_env_vars(config)
        assert result == {"key": "default_value"}

    def test_resolve_nested(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("NESTED_VAR", "nested")
        config = {"outer": {"inner": "${NESTED_VAR}"}}
        result = resolve_env_vars(config)
        assert result == {"outer": {"inner": "nested"}}


class TestLoadYamlConfig:
    """Tests for YAML configuration loading."""

    def test_load_base_config(self) -> None:
        with TemporaryDirectory() as tmpdir:
            config_dir = Path(tmpdir)
            base_dir = config_dir / "base"
            base_dir.mkdir()

            kafka_config = {"kafka": {"bootstrap_servers": "kafka:9092"}}
            with open(base_dir / "kafka.yaml", "w") as f:
                yaml.dump(kafka_config, f)

            result = load_yaml_config(config_dir, "local", ["kafka.yaml"])
            assert result["kafka"]["bootstrap_servers"] == "kafka:9092"

    def test_environment_override(self) -> None:
        with TemporaryDirectory() as tmpdir:
            config_dir = Path(tmpdir)
            base_dir = config_dir / "base"
            env_dir = config_dir / "environments"
            base_dir.mkdir()
            env_dir.mkdir()

            # Base config
            with open(base_dir / "kafka.yaml", "w") as f:
                yaml.dump({"kafka": {"bootstrap_servers": "localhost:9092"}}, f)

            # Environment override
            with open(env_dir / "prod.yaml", "w") as f:
                yaml.dump({"kafka": {"bootstrap_servers": "kafka.prod:9092"}}, f)

            result = load_yaml_config(config_dir, "prod", ["kafka.yaml"])
            assert result["kafka"]["bootstrap_servers"] == "kafka.prod:9092"


class TestKafkaConfig:
    """Tests for Kafka configuration."""

    def test_default_values(self) -> None:
        config = KafkaConfig()
        assert config.bootstrap_servers == "localhost:29092"
        assert config.security_protocol == "PLAINTEXT"

    def test_env_override(self, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setenv("DP_KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
        config = KafkaConfig()
        assert config.bootstrap_servers == "kafka:9092"


class TestDataPlatformConfig:
    """Tests for main configuration class."""

    def test_default_config(self) -> None:
        config = DataPlatformConfig()
        assert config.environment == "local"
        assert config.debug is False
        assert isinstance(config.kafka, KafkaConfig)
        assert isinstance(config.s3, S3Config)

    def test_from_yaml(self) -> None:
        with TemporaryDirectory() as tmpdir:
            config_dir = Path(tmpdir)
            base_dir = config_dir / "base"
            env_dir = config_dir / "environments"
            base_dir.mkdir()
            env_dir.mkdir()

            with open(base_dir / "kafka.yaml", "w") as f:
                yaml.dump({}, f)

            with open(env_dir / "dev.yaml", "w") as f:
                yaml.dump({"environment": "dev", "debug": True}, f)

            config = DataPlatformConfig.from_yaml(config_dir, "dev")
            assert config.environment == "dev"
            assert config.debug is True
