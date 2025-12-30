output "vpc_id" {
  description = "ID of the VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.vpc.public_subnet_ids
}

output "bronze_bucket" {
  description = "Name of the bronze bucket"
  value       = module.lakehouse.bronze_bucket_name
}

output "silver_bucket" {
  description = "Name of the silver bucket"
  value       = module.lakehouse.silver_bucket_name
}

output "gold_bucket" {
  description = "Name of the gold bucket"
  value       = module.lakehouse.gold_bucket_name
}

output "warehouse_bucket" {
  description = "Name of the Iceberg warehouse bucket"
  value       = module.lakehouse.warehouse_bucket_name
}

output "emr_serverless_role_arn" {
  description = "ARN of EMR Serverless execution role"
  value       = module.iam_roles.emr_serverless_role_arn
}

output "airflow_role_arn" {
  description = "ARN of Airflow execution role"
  value       = module.iam_roles.airflow_role_arn
}
