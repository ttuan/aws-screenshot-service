###################
# S3 Bucket for Screenshots Storage
###################
resource "aws_s3_bucket" "screenshots" {
  bucket = "${var.project}-${var.env}"

  tags = {
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

resource "aws_s3_bucket_public_access_block" "screenshots" {
  bucket = aws_s3_bucket.screenshots.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "screenshots" {
  bucket = aws_s3_bucket.screenshots.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "screenshots" {
  bucket = aws_s3_bucket.screenshots.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "screenshots" {
  bucket = aws_s3_bucket.screenshots.id

  rule {
    id     = "screenshots_lifecycle"
    status = "Enabled"

    filter {}

    expiration {
      days = 30
    }

    noncurrent_version_expiration {
      noncurrent_days = 7
    }
  }
}