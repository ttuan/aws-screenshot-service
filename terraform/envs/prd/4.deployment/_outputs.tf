###################
# Lambda Function Outputs
###################

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.screenshot_validator.arn
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.screenshot_validator.function_name
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.screenshot_validator.invoke_arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}