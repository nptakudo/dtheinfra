################################################################################
# Dev Environment Configuration
################################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

################################################################################
# Networking
################################################################################

module "vpc" {
  source = "../../modules/networking/vpc"

  project_name         = var.project_name
  environment          = var.environment
  aws_region           = var.aws_region
  vpc_cidr             = var.vpc_cidr
  az_count             = 2
  enable_nat_gateway   = var.enable_nat_gateway
  enable_vpc_endpoints = true

  tags = local.common_tags
}

################################################################################
# Storage
################################################################################

module "lakehouse" {
  source = "../../modules/storage/s3-lakehouse"

  project_name = var.project_name
  environment  = var.environment

  tags = local.common_tags
}

################################################################################
# IAM Roles
################################################################################

module "iam_roles" {
  source = "../../modules/governance/iam-roles"

  project_name   = var.project_name
  environment    = var.environment
  aws_region     = var.aws_region
  s3_bucket_arns = module.lakehouse.all_bucket_arns

  tags = local.common_tags
}
