terraform {
  required_version = ">= 1.13.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.14.0"
    }
  }
  backend "s3" {
    profile        = "screenshot-service-prd"
    bucket         = "screenshot-service-prd-iac-state"
    key            = "5.monitoring/terraform.prd.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/screenshot-service-prd-iac"
    dynamodb_table = "screenshot-service-prd-terraform-state-lock"
  }
}

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
