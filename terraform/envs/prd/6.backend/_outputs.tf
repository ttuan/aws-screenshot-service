###################
# SQS Queue Outputs
###################

output "screenshot_processing_queue_url" {
  description = "URL of the screenshot processing SQS queue"
  value       = aws_sqs_queue.screenshot_processing.url
}

output "screenshot_processing_queue_arn" {
  description = "ARN of the screenshot processing SQS queue"
  value       = aws_sqs_queue.screenshot_processing.arn
}

# Alias for Lambda compatibility
output "sqs_queue_url" {
  description = "SQS queue URL for Lambda environment variables"
  value       = aws_sqs_queue.screenshot_processing.url
}

###################
# ECS Cluster Outputs
###################

output "ecs_cluster_id" {
  description = "ID of the ECS cluster"
  value       = aws_ecs_cluster.screenshot_processing.id
}

output "ecs_cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.screenshot_processing.arn
}

output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.screenshot_processing.name
}

###################
# ECS Service Outputs
###################

output "ecs_service_id" {
  description = "ID of the ECS service"
  value       = aws_ecs_service.screenshot_processor.id
}

output "ecs_service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.screenshot_processor.name
}

output "ecs_service_cluster" {
  description = "Amazon Resource Name (ARN) of cluster which the service runs on"
  value       = aws_ecs_service.screenshot_processor.cluster
}

###################
# ECS Task Definition Outputs
###################

output "ecs_task_definition_arn" {
  description = "Full ARN of the Task Definition (including both family and revision)"
  value       = aws_ecs_task_definition.screenshot_processor.arn
}

output "ecs_task_definition_family" {
  description = "Family of the Task Definition"
  value       = aws_ecs_task_definition.screenshot_processor.family
}

output "ecs_task_definition_revision" {
  description = "Revision of the task in a particular family"
  value       = aws_ecs_task_definition.screenshot_processor.revision
}

###################
# IAM Role Outputs
###################

output "ecs_task_role_arn" {
  description = "ARN of the ECS task IAM role"
  value       = aws_iam_role.ecs_task.arn
}

output "ecs_task_execution_role_arn" {
  description = "ARN of the ECS task execution IAM role"
  value       = aws_iam_role.ecs_task_execution.arn
}

###################
# CloudWatch Log Group Output
###################

output "ecs_log_group_name" {
  description = "Name of the CloudWatch log group for ECS"
  value       = aws_cloudwatch_log_group.ecs_logs.name
}

output "ecs_log_group_arn" {
  description = "ARN of the CloudWatch log group for ECS"
  value       = aws_cloudwatch_log_group.ecs_logs.arn
}
