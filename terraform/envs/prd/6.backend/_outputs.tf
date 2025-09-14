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