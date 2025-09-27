###################
# SNS Topic Outputs
###################

output "sns_alerts_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "sns_alerts_topic_name" {
  description = "Name of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.name
}

###################
# CloudWatch Dashboard Output
###################

output "dashboard_name" {
  description = "Name of the CloudWatch dashboard"
  value       = aws_cloudwatch_dashboard.screenshot_service.dashboard_name
}

output "dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards:name=${aws_cloudwatch_dashboard.screenshot_service.dashboard_name}"
}

###################
# CloudWatch Alarms Outputs
###################

output "alarm_names" {
  description = "List of all CloudWatch alarm names"
  value = [
    aws_cloudwatch_metric_alarm.high_queue_depth.alarm_name,
    aws_cloudwatch_metric_alarm.dlq_messages.alarm_name,
    aws_cloudwatch_metric_alarm.ecs_high_cpu.alarm_name,
    aws_cloudwatch_metric_alarm.ecs_high_memory.alarm_name,
    aws_cloudwatch_metric_alarm.ecs_no_running_tasks.alarm_name,
    aws_cloudwatch_metric_alarm.lambda_errors.alarm_name,
    aws_cloudwatch_metric_alarm.lambda_duration.alarm_name,
    aws_cloudwatch_metric_alarm.slow_screenshot_processing.alarm_name
  ]
}

###################
# Email Configuration Output
###################

output "email_subscription_configured" {
  description = "Whether email subscription is configured"
  value       = var.alert_email != "" ? "Email alerts configured for: ${var.alert_email}" : "No email alerts configured. Set alert_email variable to enable email notifications."
}

###################
# Budget Outputs
###################

output "monthly_budget_name" {
  description = "Name of the monthly budget"
  value       = aws_budgets_budget.screenshot_service_monthly.name
}

output "daily_budget_name" {
  description = "Name of the daily budget"
  value       = aws_budgets_budget.screenshot_service_daily.name
}

output "ecs_budget_name" {
  description = "Name of the ECS-specific budget"
  value       = aws_budgets_budget.ecs_budget.name
}

output "budget_limits" {
  description = "Summary of all budget limits"
  value = {
    monthly_limit = "${aws_budgets_budget.screenshot_service_monthly.limit_amount} ${aws_budgets_budget.screenshot_service_monthly.limit_unit}"
    daily_limit   = "${aws_budgets_budget.screenshot_service_daily.limit_amount} ${aws_budgets_budget.screenshot_service_daily.limit_unit}"
    ecs_limit     = "${aws_budgets_budget.ecs_budget.limit_amount} ${aws_budgets_budget.ecs_budget.limit_unit}"
  }
}

###################
# Cost Anomaly Detection Outputs
# Note: Commented out until anomaly detection resources are supported
###################

# output "cost_anomaly_detector_arn" {
#   description = "ARN of the cost anomaly detector"
#   value       = aws_ce_anomaly_detector.screenshot_service.arn
# }

# output "cost_anomaly_subscription_arn" {
#   description = "ARN of the cost anomaly subscription"
#   value       = aws_ce_anomaly_subscription.screenshot_service.arn
# }
