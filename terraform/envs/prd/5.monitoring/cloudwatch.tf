###################
# KMS Key for SNS Encryption
###################

resource "aws_kms_key" "sns" {
  description             = "KMS key for SNS topic encryption"
  deletion_window_in_days = 7

  tags = {
    Name        = "${var.project}-${var.env}-sns-key"
    Environment = var.env
    Project     = var.project
    Service     = "monitoring"
    Terraform   = "true"
  }
}

resource "aws_kms_alias" "sns" {
  name          = "alias/${var.project}-${var.env}-sns"
  target_key_id = aws_kms_key.sns.key_id
}

###################
# SNS Topic for Alerts
###################

resource "aws_sns_topic" "alerts" {
  name = "${var.project}-${var.env}-alerts"

  # Enable encryption
  kms_master_key_id = aws_kms_key.sns.arn

  tags = {
    Name        = "${var.project}-${var.env}-alerts"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# Add email subscription
# resource "aws_sns_topic_subscription" "email_alerts" {
#   topic_arn = aws_sns_topic.alerts.arn
#   protocol  = "email"
#   endpoint  = "your-email@example.com"
# }

###################
# Screenshot Processing Time Metric - Simple Log-based Approach
###################

# Extract processing time from application log: "✅ Job completed: jobId - 113845 ms"
# Uses space-delimited pattern to extract processing time from the new format
resource "aws_cloudwatch_log_metric_filter" "screenshot_processing_time" {
  name           = "${var.project}-${var.env}-screenshot-processing-time"
  log_group_name = "/ecs/${var.project}-${var.env}-screenshot-processor"

  # Pattern to match and extract processing time from format: "✅ Job completed: jobId - 11845 ms"
  # Space-delimited: [✅, Job, completed:, jobId, -, processingTime, ms]
  pattern = "[w1, w2, w3, jobId, w4, processingTime, w5]"

  metric_transformation {
    name          = "ProcessingTime"
    namespace     = "Screenshot/Service"
    value         = "$processingTime"
    default_value = "0"
  }
}

###################
# CloudWatch Dashboard
###################

resource "aws_cloudwatch_dashboard" "screenshot_service" {
  dashboard_name = "${var.project}-${var.env}-monitoring-v2"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["Screenshot/Service", "ProcessingTime"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Screenshot Processing Time (Average)"
          period  = 300
          stat    = "Average"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/SQS", "ApproximateNumberOfVisibleMessages", "QueueName", "${var.project}-${var.env}-processing-queue"],
            [".", "NumberOfMessagesSent", ".", "."],
            [".", "NumberOfMessagesReceived", ".", "."],
            [".", "ApproximateNumberOfVisibleMessages", "QueueName", "${var.project}-${var.env}-processing-dlq"]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "SQS Queue Metrics (Main + DLQ)"
          period  = 300
          stat    = "Sum"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", "${var.project}-${var.env}-screenshot-processor", "ClusterName", "${var.project}-${var.env}-cluster"],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "ECS Service Utilization"
          period  = 300
          stat    = "Average"
          yAxis = {
            left = {
              min = 0
              max = 100
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "RunningTaskCount", "ServiceName", "${var.project}-${var.env}-screenshot-processor", "ClusterName", "${var.project}-${var.env}-cluster"],
            ["AWS/Lambda", "Invocations", "FunctionName", "${var.project}-${var.env}-screenshot-validator"],
            [".", "Errors", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "Service Health Metrics"
          period  = 300
          stat    = "Sum"
          yAxis = {
            left = {
              min = 0
            }
          }
        }
      }
    ]
  })
}

###################
# CloudWatch Alarms
###################

# 1. SQS Queue Depth Alarm
resource "aws_cloudwatch_metric_alarm" "high_queue_depth" {
  alarm_name          = "${var.project}-${var.env}-high-queue-depth"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "50"
  alarm_description   = "This metric monitors SQS queue depth"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = "${var.project}-${var.env}-processing-queue"
  }

  tags = {
    Name        = "${var.project}-${var.env}-high-queue-depth"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# 2. Dead Letter Queue Messages Alarm
resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  alarm_name          = "${var.project}-${var.env}-dlq-messages"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ApproximateNumberOfVisibleMessages"
  namespace           = "AWS/SQS"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors DLQ for failed messages"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    QueueName = "${var.project}-${var.env}-processing-dlq"
  }

  tags = {
    Name        = "${var.project}-${var.env}-dlq-messages"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# 3. ECS Service CPU Utilization
resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu" {
  alarm_name          = "${var.project}-${var.env}-ecs-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ECS CPU utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = "${var.project}-${var.env}-screenshot-processor"
    ClusterName = "${var.project}-${var.env}-cluster"
  }

  tags = {
    Name        = "${var.project}-${var.env}-ecs-high-cpu"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# 4. ECS Service Memory Utilization
resource "aws_cloudwatch_metric_alarm" "ecs_high_memory" {
  alarm_name          = "${var.project}-${var.env}-ecs-high-memory"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "85"
  alarm_description   = "This metric monitors ECS memory utilization"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = "${var.project}-${var.env}-screenshot-processor"
    ClusterName = "${var.project}-${var.env}-cluster"
  }

  tags = {
    Name        = "${var.project}-${var.env}-ecs-high-memory"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# 5. ECS Service Running Tasks Count
resource "aws_cloudwatch_metric_alarm" "ecs_no_running_tasks" {
  alarm_name          = "${var.project}-${var.env}-ecs-no-running-tasks"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "RunningTaskCount"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ECS running tasks count"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    ServiceName = "${var.project}-${var.env}-screenshot-processor"
    ClusterName = "${var.project}-${var.env}-cluster"
  }

  tags = {
    Name        = "${var.project}-${var.env}-ecs-no-running-tasks"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# 6. Lambda Error Rate Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "${var.project}-${var.env}-lambda-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors Lambda function errors"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = "${var.project}-${var.env}-screenshot-validator"
  }

  tags = {
    Name        = "${var.project}-${var.env}-lambda-errors"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# 7. Lambda Duration Alarm
resource "aws_cloudwatch_metric_alarm" "lambda_duration" {
  alarm_name          = "${var.project}-${var.env}-lambda-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "300"
  statistic           = "Average"
  threshold           = "25000" # 25 seconds (timeout is 30s)
  alarm_description   = "This metric monitors Lambda function duration"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    FunctionName = "${var.project}-${var.env}-screenshot-validator"
  }

  tags = {
    Name        = "${var.project}-${var.env}-lambda-duration"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# 8. Screenshot Processing Time Alarm
resource "aws_cloudwatch_metric_alarm" "slow_screenshot_processing" {
  alarm_name          = "${var.project}-${var.env}-slow-screenshot-processing"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "3"
  metric_name         = "ProcessingTime"
  namespace           = "Screenshot/Service"
  period              = "300"
  statistic           = "Average"
  threshold           = "60000" # 60 seconds
  alarm_description   = "This metric monitors screenshot processing time"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  tags = {
    Name        = "${var.project}-${var.env}-slow-screenshot-processing"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}
