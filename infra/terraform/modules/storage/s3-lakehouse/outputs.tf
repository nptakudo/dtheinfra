output "bronze_bucket_name" {
  description = "Name of the bronze layer bucket"
  value       = aws_s3_bucket.bronze.id
}

output "bronze_bucket_arn" {
  description = "ARN of the bronze layer bucket"
  value       = aws_s3_bucket.bronze.arn
}

output "silver_bucket_name" {
  description = "Name of the silver layer bucket"
  value       = aws_s3_bucket.silver.id
}

output "silver_bucket_arn" {
  description = "ARN of the silver layer bucket"
  value       = aws_s3_bucket.silver.arn
}

output "gold_bucket_name" {
  description = "Name of the gold layer bucket"
  value       = aws_s3_bucket.gold.id
}

output "gold_bucket_arn" {
  description = "ARN of the gold layer bucket"
  value       = aws_s3_bucket.gold.arn
}

output "warehouse_bucket_name" {
  description = "Name of the Iceberg warehouse bucket"
  value       = aws_s3_bucket.warehouse.id
}

output "warehouse_bucket_arn" {
  description = "ARN of the Iceberg warehouse bucket"
  value       = aws_s3_bucket.warehouse.arn
}

output "artifacts_bucket_name" {
  description = "Name of the artifacts bucket"
  value       = aws_s3_bucket.artifacts.id
}

output "artifacts_bucket_arn" {
  description = "ARN of the artifacts bucket"
  value       = aws_s3_bucket.artifacts.arn
}

output "all_bucket_arns" {
  description = "ARNs of all lakehouse buckets"
  value = [
    aws_s3_bucket.bronze.arn,
    aws_s3_bucket.silver.arn,
    aws_s3_bucket.gold.arn,
    aws_s3_bucket.warehouse.arn,
    aws_s3_bucket.artifacts.arn,
  ]
}
