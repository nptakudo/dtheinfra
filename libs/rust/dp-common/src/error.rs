//! Error types for data platform services.

use thiserror::Error;

/// Result type alias using the platform Error type.
pub type Result<T> = std::result::Result<T, Error>;

/// Main error type for data platform services.
#[derive(Error, Debug)]
pub enum Error {
    #[error("Configuration error: {0}")]
    Config(#[from] config::ConfigError),

    #[error("Kafka error: {message}")]
    Kafka { message: String },

    #[error("S3 error: {message}")]
    S3 { message: String },

    #[error("Serialization error: {0}")]
    Serialization(#[from] serde_json::Error),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),

    #[error("Validation error: {field} - {message}")]
    Validation { field: String, message: String },

    #[error("Internal error: {0}")]
    Internal(String),
}

impl Error {
    /// Create a new Kafka error.
    pub fn kafka(message: impl Into<String>) -> Self {
        Self::Kafka {
            message: message.into(),
        }
    }

    /// Create a new S3 error.
    pub fn s3(message: impl Into<String>) -> Self {
        Self::S3 {
            message: message.into(),
        }
    }

    /// Create a new validation error.
    pub fn validation(field: impl Into<String>, message: impl Into<String>) -> Self {
        Self::Validation {
            field: field.into(),
            message: message.into(),
        }
    }

    /// Create a new internal error.
    pub fn internal(message: impl Into<String>) -> Self {
        Self::Internal(message.into())
    }
}
