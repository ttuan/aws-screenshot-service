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

# IAM Role outputs for Lambda
output "lambda_screenshot_validator_role_arn" {
  value       = aws_iam_role.lambda_screenshot_validator.arn
  description = "ARN of the Lambda screenshot validator IAM role"
}

output "lambda_screenshot_status_checker_role_arn" {
  value       = aws_iam_role.lambda_screenshot_status_checker.arn
  description = "ARN of the Lambda screenshot status checker IAM role"
}
