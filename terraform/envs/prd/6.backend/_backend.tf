terraform {
  backend "s3" {
    profile = "screenshot-service-prd"
    bucket  = "screenshot-service-prd-iac-state"
    key     = "6.backend/terraform.prd.tfstate"
    region  = "us-east-1"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:us-east-1:534929761277:key/db485ffd-7bf1-43b2-9421-ebff58e40734"
    dynamodb_table = "screenshot-service-prd-terraform-state-lock"
  }
}

# Configure the AWS Provider
provider "aws" {
  region  = var.region
  profile = "${var.project}-${var.env}"
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.env
    }
  }
}

data "aws_caller_identity" "current" {}
