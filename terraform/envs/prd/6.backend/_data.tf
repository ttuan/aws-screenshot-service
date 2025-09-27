###################
# Data Sources for ECS Integration
###################

# Get VPC information from general module
data "terraform_remote_state" "general" {
  backend = "s3"
  config = {
    bucket = "screenshot-service-prd-iac-state"
    key    = "1.general/terraform.prd.tfstate"
    region = "us-east-1"
  }
}

# Get database information
data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket = "screenshot-service-prd-iac-state"
    key    = "3.database/terraform.prd.tfstate"
    region = "us-east-1"
  }
}

# SNS KMS key now comes from general module

# Get current AWS region
data "aws_region" "current" {}

# Get private subnets for ECS tasks
data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.terraform_remote_state.general.outputs.vpc_id]
  }

  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}
