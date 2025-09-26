###################
# ECS Task Execution Role
###################

# ECS Task Execution Role - Used by ECS to pull images and write logs
resource "aws_iam_role" "ecs_task_execution" {
  name = "${var.project}-${var.env}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-ecs-task-execution-role"
    Environment = var.env
    Project     = var.project
    Service     = "screenshot-processing"
    Terraform   = "true"
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

###################
# ECS Task Role
###################

# ECS Task Role - Used by the application running in the container
resource "aws_iam_role" "ecs_task" {
  name = "${var.project}-${var.env}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-ecs-task-role"
    Environment = var.env
    Project     = var.project
    Service     = "screenshot-processing"
    Terraform   = "true"
  }
}

###################
# SQS Access Policy
###################

resource "aws_iam_policy" "ecs_sqs_policy" {
  name        = "${var.project}-${var.env}-ecs-sqs-policy"
  description = "Policy for ECS task to access SQS queue"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = [
          aws_sqs_queue.screenshot_processing.arn,
          aws_sqs_queue.screenshot_processing_dlq.arn
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-ecs-sqs-policy"
    Environment = var.env
    Project     = var.project
    Service     = "screenshot-processing"
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_sqs_policy" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_sqs_policy.arn
}

###################
# S3 Access Policy
###################

resource "aws_iam_policy" "ecs_s3_policy" {
  name        = "${var.project}-${var.env}-ecs-s3-policy"
  description = "Policy for ECS task to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          data.terraform_remote_state.general.outputs.screenshots_bucket_arn,
          "${data.terraform_remote_state.general.outputs.screenshots_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-ecs-s3-policy"
    Environment = var.env
    Project     = var.project
    Service     = "screenshot-processing"
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_policy" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_s3_policy.arn
}

###################
# DynamoDB Access Policy
###################

resource "aws_iam_policy" "ecs_dynamodb_policy" {
  name        = "${var.project}-${var.env}-ecs-dynamodb-policy"
  description = "Policy for ECS task to access DynamoDB table"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = data.terraform_remote_state.database.outputs.screenshot_jobs_table_arn
      }
    ]
  })

  tags = {
    Name        = "${var.project}-${var.env}-ecs-dynamodb-policy"
    Environment = var.env
    Project     = var.project
    Service     = "screenshot-processing"
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_dynamodb_policy" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = aws_iam_policy.ecs_dynamodb_policy.arn
}

# Minimal policy for ECS Execute Command
resource "aws_iam_role_policy_attachment" "ecs_task_ssm_policy" {
  role       = aws_iam_role.ecs_task.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

