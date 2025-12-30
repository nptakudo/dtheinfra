//! Configuration management for data platform services.

use config::{ConfigError, Environment, File};
use serde::Deserialize;
use std::path::Path;

/// Main configuration struct for data platform services.
#[derive(Debug, Clone, Deserialize)]
pub struct Config {
    pub environment: String,
    pub debug: bool,
    pub kafka: KafkaConfig,
    pub s3: S3Config,
}

/// Kafka connection configuration.
#[derive(Debug, Clone, Deserialize)]
pub struct KafkaConfig {
    pub bootstrap_servers: String,
    pub schema_registry_url: String,
    pub security_protocol: String,
}

/// S3/MinIO configuration.
#[derive(Debug, Clone, Deserialize)]
pub struct S3Config {
    pub endpoint_url: Option<String>,
    pub bucket_bronze: String,
    pub bucket_silver: String,
    pub bucket_gold: String,
    pub region: String,
}

impl Config {
    /// Load configuration from files and environment variables.
    ///
    /// Configuration is loaded in the following order (later sources override earlier):
    /// 1. Base config file (if exists)
    /// 2. Environment-specific config file (if exists)
    /// 3. Environment variables (prefix: DP_)
    pub fn load(config_dir: Option<&Path>) -> Result<Self, ConfigError> {
        let environment = std::env::var("DP_ENVIRONMENT").unwrap_or_else(|_| "local".to_string());

        let mut builder = config::Config::builder();

        // Load base config if directory provided
        if let Some(dir) = config_dir {
            let base_path = dir.join("base").join("config.yaml");
            if base_path.exists() {
                builder = builder.add_source(File::from(base_path).required(false));
            }

            // Load environment-specific config
            let env_path = dir.join("environments").join(format!("{}.yaml", environment));
            if env_path.exists() {
                builder = builder.add_source(File::from(env_path).required(false));
            }
        }

        // Override with environment variables
        builder = builder.add_source(
            Environment::with_prefix("DP")
                .separator("__")
                .try_parsing(true),
        );

        builder.build()?.try_deserialize()
    }
}

impl Default for Config {
    fn default() -> Self {
        Self {
            environment: "local".to_string(),
            debug: false,
            kafka: KafkaConfig {
                bootstrap_servers: "localhost:29092".to_string(),
                schema_registry_url: "http://localhost:8081".to_string(),
                security_protocol: "PLAINTEXT".to_string(),
            },
            s3: S3Config {
                endpoint_url: Some("http://localhost:9000".to_string()),
                bucket_bronze: "bronze".to_string(),
                bucket_silver: "silver".to_string(),
                bucket_gold: "gold".to_string(),
                region: "us-east-1".to_string(),
            },
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_default_config() {
        let config = Config::default();
        assert_eq!(config.environment, "local");
        assert!(!config.debug);
    }
}
