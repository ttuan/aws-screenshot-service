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
