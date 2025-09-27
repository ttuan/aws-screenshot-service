output "aws_account_id" {
  value       = <<VALUE

  Check AWS Env:
    Project : "${var.project}" | Env: "${var.env}"
    AWS Account ID: "${data.aws_caller_identity.current.account_id}"
    AWS Account ARN: "${data.aws_caller_identity.current.arn}"
  VALUE
  description = "Show information about project, environment and account"
}

#Output modules
output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "ID of VPC"
}

# S3 Bucket outputs
output "screenshots_bucket_name" {
  value       = aws_s3_bucket.screenshots.bucket
  description = "Name of the screenshots S3 bucket"
}

output "screenshots_bucket_arn" {
  value       = aws_s3_bucket.screenshots.arn
  description = "ARN of the screenshots S3 bucket"
}

# KMS Key outputs
output "s3_kms_key_arn" {
  value       = aws_kms_key.s3.arn
  description = "ARN of the S3 KMS key"
}

output "s3_kms_key_id" {
  value       = aws_kms_key.s3.key_id
  description = "ID of the S3 KMS key"
}

# IAM Role outputs for Lambda
output "lambda_screenshot_validator_role_arn" {
  value       = aws_iam_role.lambda_screenshot_validator.arn
  description = "ARN of the Lambda screenshot validator IAM role"
}

output "lambda_screenshot_status_checker_role_arn" {
  value       = aws_iam_role.lambda_screenshot_status_checker.arn
  description = "ARN of the Lambda screenshot status checker IAM role"
}

# VPC Endpoints outputs
output "vpc_endpoint_s3_id" {
  value       = aws_vpc_endpoint.s3.id
  description = "ID of the S3 VPC endpoint"
}

output "vpc_endpoint_dynamodb_id" {
  value       = aws_vpc_endpoint.dynamodb.id
  description = "ID of the DynamoDB VPC endpoint"
}

output "vpc_endpoints_security_group_id" {
  value       = aws_security_group.vpc_endpoints.id
  description = "ID of the security group for VPC endpoints"
}

# SNS KMS Key outputs
output "sns_kms_key_arn" {
  value       = aws_kms_key.sns.arn
  description = "ARN of the SNS KMS key"
}

output "sns_kms_key_id" {
  value       = aws_kms_key.sns.key_id
  description = "ID of the SNS KMS key"
}

# SQS KMS Key outputs
output "sqs_kms_key_arn" {
  value       = aws_kms_key.sqs.arn
  description = "ARN of the SQS KMS key"
}

output "sqs_kms_key_id" {
  value       = aws_kms_key.sqs.key_id
  description = "ID of the SQS KMS key"
}
