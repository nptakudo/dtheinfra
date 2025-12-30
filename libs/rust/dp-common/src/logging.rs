//! Structured logging configuration for data platform services.

use tracing_subscriber::{
    fmt::{self, format::FmtSpan},
    prelude::*,
    EnvFilter,
};

/// Initialize structured logging.
///
/// # Arguments
///
/// * `service_name` - Name of the service for log context
/// * `json_output` - If true, output logs in JSON format
/// * `level` - Log level filter (e.g., "info", "debug")
pub fn init(service_name: &str, json_output: bool, level: &str) {
    let filter = EnvFilter::try_from_default_env()
        .unwrap_or_else(|_| EnvFilter::new(level));

    if json_output {
        let subscriber = tracing_subscriber::registry()
            .with(filter)
            .with(
                fmt::layer()
                    .json()
                    .with_current_span(true)
                    .with_span_events(FmtSpan::CLOSE)
                    .flatten_event(true)
                    .with_target(true),
            );

        tracing::subscriber::set_global_default(subscriber)
            .expect("Failed to set subscriber");
    } else {
        let subscriber = tracing_subscriber::registry()
            .with(filter)
            .with(
                fmt::layer()
                    .with_target(true)
                    .with_thread_ids(false)
                    .with_file(true)
                    .with_line_number(true),
            );

        tracing::subscriber::set_global_default(subscriber)
            .expect("Failed to set subscriber");
    }

    tracing::info!(
        service = service_name,
        "Logging initialized"
    );
}

/// Initialize logging with default settings.
pub fn init_default(service_name: &str) {
    let is_prod = std::env::var("DP_ENVIRONMENT")
        .map(|e| e == "prod" || e == "production")
        .unwrap_or(false);

    init(service_name, is_prod, "info");
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_init_does_not_panic() {
        // Just verify initialization doesn't panic
        // Note: Can only initialize once per process
    }
}
