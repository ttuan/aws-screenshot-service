###################
# AWS Budgets for Cost Monitoring
###################

# Monthly Budget for Screenshot Service
resource "aws_budgets_budget" "screenshot_service_monthly" {
  name              = "${var.project}-${var.env}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = tostring(var.monthly_budget_limit)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  cost_filter {
    name   = "TagKeyValue"
    values = [format("Project$%s", var.project)]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80 # Alert at 80% of budget
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.alerts.arn]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100 # Alert at 100% of budget
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_email != "" ? [var.alert_email] : []
    subscriber_sns_topic_arns  = [aws_sns_topic.alerts.arn]
  }

  tags = {
    Name        = "${var.project}-${var.env}-monthly-budget"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# Daily Budget for High Spend Detection
resource "aws_budgets_budget" "screenshot_service_daily" {
  name              = "${var.project}-${var.env}-daily-budget"
  budget_type       = "COST"
  limit_amount      = tostring(var.daily_budget_limit)
  limit_unit        = "USD"
  time_unit         = "DAILY"
  time_period_start = "2024-01-01_00:00"

  cost_filter {
    name   = "TagKeyValue"
    values = [format("Project$%s", var.project)]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 100 # Alert at 100% of daily budget
    threshold_type            = "PERCENTAGE"
    notification_type         = "ACTUAL"
    subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
  }

  tags = {
    Name        = "${var.project}-${var.env}-daily-budget"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# ECS-specific Budget (highest cost component)
resource "aws_budgets_budget" "ecs_budget" {
  name              = "${var.project}-${var.env}-ecs-budget"
  budget_type       = "COST"
  limit_amount      = tostring(var.ecs_budget_limit)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2024-01-01_00:00"

  cost_filter {
    name   = "Service"
    values = ["Amazon Elastic Container Service"]
  }

  cost_filter {
    name   = "TagKeyValue"
    values = [format("Project$%s", var.project)]
  }

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 90 # Alert at 90% of ECS budget
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.alerts.arn]
  }

  tags = {
    Name        = "${var.project}-${var.env}-ecs-budget"
    Environment = var.env
    Project     = var.project
    Service     = "ecs"
    Terraform   = "true"
  }
}

###################
# Cost Anomaly Detection
# Note: AWS Cost Explorer Anomaly Detection resources are not yet supported
# in the Terraform AWS provider. These will need to be configured manually
# through the AWS Console or AWS CLI until provider support is added.
###################

# TODO: Implement cost anomaly detection once aws_ce_anomaly_detector
# and aws_ce_anomaly_subscription resources are supported in the provider
