###################
# Lambda Assume Role Policy
###################
data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

###################
# SQS Access Policy for Lambda
###################
data "aws_iam_policy_document" "lambda_sqs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sqs:SendMessage"
    ]
    resources = [
      "arn:aws:sqs:${var.region}:${data.aws_caller_identity.current.account_id}:${var.project}-${var.env}-processing-queue"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "dynamodb:PutItem",
      "dynamodb:GetItem"
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.project}-${var.env}-jobs"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project}-${var.env}-*",
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project}-${var.env}-*:*"
    ]
  }

  # KMS permissions for Lambda to access encrypted SQS
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [
      "arn:aws:kms:${var.region}:${data.aws_caller_identity.current.account_id}:key/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "kms:ViaService"
      values   = ["sqs.${var.region}.amazonaws.com"]
    }
  }
}

###################
# Lambda IAM Role for Screenshot Request Validator
###################
resource "aws_iam_role" "lambda_screenshot_validator" {
  name               = "${var.project}-${var.env}-lambda-screenshot-validator-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name    = "${var.project}-${var.env}-lambda-screenshot-validator-role"
    Service = "lambda"
  }
}

resource "aws_iam_role_policy" "lambda_screenshot_validator_policy" {
  name   = "${var.project}-${var.env}-lambda-screenshot-validator-policy"
  role   = aws_iam_role.lambda_screenshot_validator.id
  policy = data.aws_iam_policy_document.lambda_sqs_policy.json
}

###################
# S3 and DynamoDB Access Policy for Status Checker Lambda
###################
data "aws_iam_policy_document" "lambda_status_checker_policy" {
  statement {
    effect = "Allow"
    actions = [
      "dynamodb:GetItem"
    ]
    resources = [
      "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/${var.project}-${var.env}-jobs"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::${var.project}-${var.env}/*"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project}-${var.env}-*",
      "arn:aws:logs:${var.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project}-${var.env}-*:*"
    ]
  }

  # KMS permissions for Lambda to access encrypted S3
  statement {
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:DescribeKey"
    ]
    resources = [
      aws_kms_key.s3.arn
    ]
  }
}

###################
# Lambda IAM Role for Screenshot Status Checker
###################
resource "aws_iam_role" "lambda_screenshot_status_checker" {
  name               = "${var.project}-${var.env}-lambda-status-checker-role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json

  tags = {
    Name    = "${var.project}-${var.env}-lambda-status-checker-role"
    Service = "lambda"
  }
}

resource "aws_iam_role_policy" "lambda_screenshot_status_checker_policy" {
  name   = "${var.project}-${var.env}-lambda-status-checker-policy"
  role   = aws_iam_role.lambda_screenshot_status_checker.id
  policy = data.aws_iam_policy_document.lambda_status_checker_policy.json
}
