"""Custom exceptions for the data platform."""

from __future__ import annotations

from typing import Any


class DataPlatformError(Exception):
    """Base exception for all data platform errors."""

    def __init__(
        self,
        message: str,
        *,
        details: dict[str, Any] | None = None,
        cause: Exception | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.details = details or {}
        self.cause = cause

    def __str__(self) -> str:
        base = self.message
        if self.details:
            base += f" | Details: {self.details}"
        if self.cause:
            base += f" | Caused by: {self.cause}"
        return base


class ConfigurationError(DataPlatformError):
    """Raised when there's a configuration-related error."""

    pass


class ConnectionError(DataPlatformError):
    """Raised when there's a connection error to external services."""

    def __init__(
        self,
        message: str,
        *,
        service: str,
        host: str | None = None,
        port: int | None = None,
        **kwargs: Any,
    ) -> None:
        details = {"service": service}
        if host:
            details["host"] = host
        if port:
            details["port"] = port
        super().__init__(message, details=details, **kwargs)
        self.service = service
        self.host = host
        self.port = port


class ValidationError(DataPlatformError):
    """Raised when data validation fails."""

    def __init__(
        self,
        message: str,
        *,
        field: str | None = None,
        value: Any = None,
        constraint: str | None = None,
        **kwargs: Any,
    ) -> None:
        details: dict[str, Any] = {}
        if field:
            details["field"] = field
        if value is not None:
            details["value"] = str(value)[:100]  # Truncate for safety
        if constraint:
            details["constraint"] = constraint
        super().__init__(message, details=details, **kwargs)
        self.field = field
        self.value = value
        self.constraint = constraint


class SchemaError(DataPlatformError):
    """Raised when there's a schema-related error."""

    def __init__(
        self,
        message: str,
        *,
        schema_name: str | None = None,
        schema_version: str | None = None,
        **kwargs: Any,
    ) -> None:
        details: dict[str, Any] = {}
        if schema_name:
            details["schema_name"] = schema_name
        if schema_version:
            details["schema_version"] = schema_version
        super().__init__(message, details=details, **kwargs)
        self.schema_name = schema_name
        self.schema_version = schema_version


class DataQualityError(DataPlatformError):
    """Raised when data quality checks fail."""

    def __init__(
        self,
        message: str,
        *,
        check_name: str,
        table: str | None = None,
        column: str | None = None,
        expected: Any = None,
        actual: Any = None,
        **kwargs: Any,
    ) -> None:
        details = {"check_name": check_name}
        if table:
            details["table"] = table
        if column:
            details["column"] = column
        if expected is not None:
            details["expected"] = str(expected)
        if actual is not None:
            details["actual"] = str(actual)
        super().__init__(message, details=details, **kwargs)
        self.check_name = check_name
        self.table = table
        self.column = column


class RetryableError(DataPlatformError):
    """Raised for errors that can be retried."""

    def __init__(
        self,
        message: str,
        *,
        retry_after_seconds: int | None = None,
        max_retries: int | None = None,
        **kwargs: Any,
    ) -> None:
        details: dict[str, Any] = {}
        if retry_after_seconds:
            details["retry_after_seconds"] = retry_after_seconds
        if max_retries:
            details["max_retries"] = max_retries
        super().__init__(message, details=details, **kwargs)
        self.retry_after_seconds = retry_after_seconds
        self.max_retries = max_retries
