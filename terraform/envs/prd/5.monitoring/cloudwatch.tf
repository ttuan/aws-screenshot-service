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
            [".", "NumberOfMessagesReceived", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.region
          title   = "SQS Queue Metrics"
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
