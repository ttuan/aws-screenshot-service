# DynamoDB Table outputs
output "screenshot_jobs_table_name" {
  value       = aws_dynamodb_table.screenshot_jobs.name
  description = "Name of the screenshot jobs DynamoDB table"
}

output "screenshot_jobs_table_arn" {
  value       = aws_dynamodb_table.screenshot_jobs.arn
  description = "ARN of the screenshot jobs DynamoDB table"
}
