###################
# Lambda Function for Screenshot Validator
###################

resource "aws_lambda_function" "screenshot_validator" {
  function_name    = "${var.project}-${var.env}-screenshot-validator"
  role            = data.terraform_remote_state.general.outputs.lambda_screenshot_validator_role_arn
  handler         = "index.handler"
  runtime         = "nodejs20.x"
  filename        = "lambda_functions/screenshot-validator/screenshot-validator.zip"
  source_code_hash = filebase64sha256("lambda_functions/screenshot-validator/screenshot-validator.zip")
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      SQS_QUEUE_URL  = data.terraform_remote_state.backend.outputs.sqs_queue_url
      DYNAMODB_TABLE = data.terraform_remote_state.database.outputs.dynamodb_table_name
      NODE_ENV       = "production"
    }
  }

  tags = {
    Name        = "${var.project}-${var.env}-screenshot-validator"
    Service     = "screenshot-processing"
    Environment = var.env
  }
}

###################
# CloudWatch Log Group
###################

resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.screenshot_validator.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "/aws/lambda/${aws_lambda_function.screenshot_validator.function_name}"
    Service     = "screenshot-processing"
    Environment = var.env
  }
}

###################
# Lambda Function for Screenshot Status Checker
###################

resource "aws_lambda_function" "screenshot_status_checker" {
  function_name    = "${var.project}-${var.env}-screenshot-status-checker"
  role            = data.terraform_remote_state.general.outputs.lambda_screenshot_status_checker_role_arn
  handler         = "index.handler"
  runtime         = "nodejs20.x"
  filename        = "lambda_functions/screenshot-status.zip"
  source_code_hash = filebase64sha256("lambda_functions/screenshot-status.zip")
  timeout         = 30
  memory_size     = 256

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = data.terraform_remote_state.database.outputs.dynamodb_table_name
      S3_BUCKET_NAME      = data.terraform_remote_state.general.outputs.screenshots_bucket_name
      NODE_ENV            = "production"
    }
  }

  tags = {
    Name        = "${var.project}-${var.env}-screenshot-status-checker"
    Service     = "screenshot-processing"
    Environment = var.env
  }
}

###################
# CloudWatch Log Group for Status Checker
###################

resource "aws_cloudwatch_log_group" "lambda_status_checker_logs" {
  name              = "/aws/lambda/${aws_lambda_function.screenshot_status_checker.function_name}"
  retention_in_days = 14

  tags = {
    Name        = "/aws/lambda/${aws_lambda_function.screenshot_status_checker.function_name}"
    Service     = "screenshot-processing"
    Environment = var.env
  }
}
