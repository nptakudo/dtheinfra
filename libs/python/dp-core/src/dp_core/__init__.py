"""Core utilities for the data platform."""

from dp_core.config import DataPlatformConfig, get_config
from dp_core.exceptions import (
    DataPlatformError,
    ConfigurationError,
    ConnectionError,
    ValidationError,
)
from dp_core.logging import configure_logging, get_logger

__all__ = [
    "DataPlatformConfig",
    "get_config",
    "DataPlatformError",
    "ConfigurationError",
    "ConnectionError",
    "ValidationError",
    "configure_logging",
    "get_logger",
]

__version__ = "0.1.0"
