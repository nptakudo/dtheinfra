//! Common utilities for the data platform Rust services.
//!
//! This crate provides shared functionality including:
//! - Configuration management
//! - Structured logging
//! - Error types
//! - Common utilities

pub mod config;
pub mod error;
pub mod logging;

pub use config::Config;
pub use error::{Error, Result};
