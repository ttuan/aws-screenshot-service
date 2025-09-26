###################
# ECS Cluster for Screenshot Processing
###################

resource "aws_ecs_cluster" "screenshot_processing" {
  name = "${var.project}-${var.env}-cluster"

  tags = {
    Name        = "${var.project}-${var.env}-cluster"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

###################
# Task Definition
###################

resource "aws_ecs_task_definition" "screenshot_processor" {
  family                   = "${var.project}-${var.env}-screenshot-processor"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048

  execution_role_arn = aws_iam_role.ecs_task_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name  = "screenshot-processor"
      image = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com/${var.project}-${var.env}:${var.container_image_tag}"

      essential = true

      # Environment variables
      environment = [
        {
          name  = "SQS_QUEUE_URL"
          value = aws_sqs_queue.screenshot_processing.url
        },
        {
          name  = "S3_BUCKET_NAME"
          value = data.terraform_remote_state.general.outputs.screenshots_bucket_name
        },
        {
          name  = "DYNAMODB_TABLE_NAME"
          value = data.terraform_remote_state.database.outputs.screenshot_jobs_table_name
        },
        {
          name  = "AWS_REGION"
          value = data.aws_region.current.id
        }
      ]

      # Logging configuration
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_logs.name
          "awslogs-region"        = data.aws_region.current.id
          "awslogs-stream-prefix" = "ecs"
        }
      }

    }
  ])

  tags = {
    Name        = "${var.project}-${var.env}-screenshot-processor"
    Environment = var.env
    Project     = var.project
    Service     = "screenshot-processing"
    Terraform   = "true"
  }
}

###################
# CloudWatch Log Group for ECS
###################

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.project}-${var.env}-screenshot-processor"
  retention_in_days = 7

  tags = {
    Name        = "${var.project}-${var.env}-ecs-logs"
    Environment = var.env
    Project     = var.project
    Service     = "screenshot-processing"
    Terraform   = "true"
  }
}

###################
# ECS Service
###################

resource "aws_ecs_service" "screenshot_processor" {
  name            = "${var.project}-${var.env}-screenshot-processor"
  cluster         = aws_ecs_cluster.screenshot_processing.id
  task_definition = aws_ecs_task_definition.screenshot_processor.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  enable_execute_command = true

  network_configuration {
    subnets          = data.aws_subnets.private.ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }


  tags = {
    Name        = "${var.project}-${var.env}-screenshot-processor-service"
    Environment = var.env
    Project     = var.project
    Service     = "screenshot-processing"
    Terraform   = "true"
  }

}
