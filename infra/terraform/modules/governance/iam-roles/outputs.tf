output "emr_serverless_role_arn" {
  description = "ARN of the EMR Serverless execution role"
  value       = aws_iam_role.emr_serverless.arn
}

output "emr_serverless_role_name" {
  description = "Name of the EMR Serverless execution role"
  value       = aws_iam_role.emr_serverless.name
}

output "flink_role_arn" {
  description = "ARN of the Flink execution role"
  value       = aws_iam_role.flink.arn
}

output "flink_role_name" {
  description = "Name of the Flink execution role"
  value       = aws_iam_role.flink.name
}

output "airflow_role_arn" {
  description = "ARN of the Airflow execution role"
  value       = aws_iam_role.airflow.arn
}

output "airflow_role_name" {
  description = "Name of the Airflow execution role"
  value       = aws_iam_role.airflow.name
}

output "ecs_task_role_arn" {
  description = "ARN of the ECS task role"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_execution_role_arn" {
  description = "ARN of the ECS execution role"
  value       = aws_iam_role.ecs_execution.arn
}
