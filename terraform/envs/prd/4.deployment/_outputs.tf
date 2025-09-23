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

###################
# API Gateway Outputs
###################

output "api_gateway_url" {
  description = "API Gateway URL"
  value       = "https://${aws_api_gateway_rest_api.screenshot_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}"
}

output "screenshot_endpoint" {
  description = "Screenshot endpoint URL"
  value       = "https://${aws_api_gateway_rest_api.screenshot_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/api/screenshot"
}

output "status_endpoint" {
  description = "Status endpoint URL (append /{jobId})"
  value       = "https://${aws_api_gateway_rest_api.screenshot_api.id}.execute-api.${data.aws_region.current.name}.amazonaws.com/${aws_api_gateway_stage.prod.stage_name}/api/status"
}
