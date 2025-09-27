###################
# KMS Key for SQS Encryption
###################

resource "aws_kms_key" "sqs" {
  description             = "KMS key for SQS queue encryption"
  deletion_window_in_days = 7

  tags = {
    Name        = "${var.project}-${var.env}-sqs-key"
    Environment = var.env
    Project     = var.project
    Service     = "screenshot-processing"
    Terraform   = "true"
  }
}

resource "aws_kms_alias" "sqs" {
  name          = "alias/${var.project}-${var.env}-sqs"
  target_key_id = aws_kms_key.sqs.key_id
}

###################
# Dead Letter Queue (DLQ) for Failed Messages
###################

resource "aws_sqs_queue" "screenshot_processing_dlq" {
  name = "${var.project}-${var.env}-processing-dlq"

  # DLQ configuration
  message_retention_seconds = 1209600 # 14 days

  # Enable encryption
  kms_master_key_id                 = aws_kms_key.sqs.arn
  kms_data_key_reuse_period_seconds = 300

  tags = {
    Name        = "${var.project}-${var.env}-processing-dlq"
    Environment = var.env
    Project     = var.project
    Service     = "screenshot-processing"
    Type        = "dlq"
    Terraform   = "true"
  }
}

###################
# Main SQS Screenshot Processing Queue
###################

resource "aws_sqs_queue" "screenshot_processing" {
  name = "${var.project}-${var.env}-processing-queue"

  # Enhanced queue configuration for screenshot processing
  visibility_timeout_seconds = 900     # 15 minutes (increased from 5 min for Chrome processing)
  message_retention_seconds  = 1209600 # 14 days

  # Enable server-side encryption
  kms_master_key_id                 = aws_kms_key.sqs.arn
  kms_data_key_reuse_period_seconds = 300

  # Dead Letter Queue configuration
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.screenshot_processing_dlq.arn
    maxReceiveCount     = 3 # Max retries before sending to DLQ
  })

  tags = {
    Name        = "${var.project}-${var.env}-processing-queue"
    Environment = var.env
    Project     = var.project
    Service     = "screenshot-processing"
    Type        = "main-queue"
    Terraform   = "true"
  }
}
