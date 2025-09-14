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
      "arn:aws:sqs:${var.region}:*:${var.project}-${var.env}-processing-queue"
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
      "arn:aws:logs:${var.region}:*:*"
    ]
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
