.PHONY: help install lint format test build clean local-up local-down

# Default target
help:
	@echo "Data Platform - Development Commands"
	@echo ""
	@echo "Setup:"
	@echo "  install       - Install all dependencies (Python, pre-commit)"
	@echo "  setup-hooks   - Set up pre-commit hooks"
	@echo ""
	@echo "Development:"
	@echo "  lint          - Run all linters"
	@echo "  format        - Format all code"
	@echo "  test          - Run all tests"
	@echo "  build         - Build all projects"
	@echo ""
	@echo "Python:"
	@echo "  py-lint       - Lint Python code"
	@echo "  py-format     - Format Python code"
	@echo "  py-test       - Run Python tests"
	@echo ""
	@echo "Scala:"
	@echo "  scala-compile - Compile Scala projects"
	@echo "  scala-test    - Run Scala tests"
	@echo "  scala-fmt     - Format Scala code"
	@echo ""
	@echo "Rust:"
	@echo "  rust-build    - Build Rust projects"
	@echo "  rust-test     - Run Rust tests"
	@echo "  rust-fmt      - Format Rust code"
	@echo ""
	@echo "Terraform:"
	@echo "  tf-fmt        - Format Terraform code"
	@echo "  tf-validate   - Validate Terraform configurations"
	@echo ""
	@echo "Local Development:"
	@echo "  local-up      - Start local Docker environment (full stack)"
	@echo "  local-up-core - Start core services only"
	@echo "  local-down    - Stop local Docker environment"
	@echo "  local-logs    - View local Docker logs"
	@echo ""
	@echo "Cleanup:"
	@echo "  clean         - Clean build artifacts"

# ============================================
# Setup
# ============================================

install:
	@echo "Installing Python dependencies..."
	uv sync --all-extras
	@echo "Installing pre-commit hooks..."
	uv run pre-commit install
	@echo "Done!"

setup-hooks:
	uv run pre-commit install

# ============================================
# All Languages
# ============================================

lint: py-lint rust-lint tf-fmt
	@echo "All linting complete!"

format: py-format scala-fmt rust-fmt tf-fmt
	@echo "All formatting complete!"

test: py-test scala-test rust-test
	@echo "All tests complete!"

build: scala-compile rust-build
	@echo "All builds complete!"

# ============================================
# Python
# ============================================

py-lint:
	uv run ruff check .
	uv run mypy libs/python/

py-format:
	uv run ruff format .
	uv run ruff check --fix .

py-test:
	uv run pytest -v

# ============================================
# Scala
# ============================================

scala-compile:
	sbt compile

scala-test:
	sbt test

scala-fmt:
	sbt scalafmtAll

scala-fmt-check:
	sbt scalafmtCheckAll

# ============================================
# Rust
# ============================================

rust-build:
	cargo build --all

rust-test:
	cargo test --all

rust-fmt:
	cargo fmt --all

rust-lint:
	cargo clippy --all-targets --all-features -- -D warnings

# ============================================
# Terraform
# ============================================

tf-fmt:
	terraform fmt -recursive infra/terraform/

tf-validate:
	@for env in dev staging prod; do \
		echo "Validating $$env environment..."; \
		cd infra/terraform/environments/$$env && \
		terraform init -backend=false && \
		terraform validate && \
		cd ../../../..; \
	done

# ============================================
# Local Development
# ============================================

local-up:
	cd local && docker-compose up -d

local-up-core:
	cd local && docker-compose -f docker-compose.core.yml up -d

local-down:
	cd local && docker-compose down

local-down-clean:
	cd local && docker-compose down -v

local-logs:
	cd local && docker-compose logs -f

local-ps:
	cd local && docker-compose ps

# ============================================
# Cleanup
# ============================================

clean:
	@echo "Cleaning Python artifacts..."
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".mypy_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name ".ruff_cache" -exec rm -rf {} + 2>/dev/null || true
	find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
	@echo "Cleaning Scala artifacts..."
	rm -rf target/ project/target/ 2>/dev/null || true
	@echo "Cleaning Rust artifacts..."
	cargo clean 2>/dev/null || true
	@echo "Clean complete!"
