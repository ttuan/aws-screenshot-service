###################
# SQS Screenshot Processing Queue
###################

# Main processing queue for screenshot generation jobs
resource "aws_sqs_queue" "screenshot_processing" {
  name = "${var.project}-${var.env}-processing-queue"

  # Basic queue configuration
  visibility_timeout_seconds = 300     # 5 minutes
  message_retention_seconds  = 1209600 # 14 days

  tags = {
    Name    = "${var.project}-${var.env}-processing-queue"
    Service = "screenshot-processing"
  }
}

