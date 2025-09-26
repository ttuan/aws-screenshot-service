# Get ECS log group name from backend module
data "terraform_remote_state" "backend" {
  backend = "s3"
  config = {
    bucket = "screenshot-service-prd-iac-state"
    key    = "6.backend/terraform.prd.tfstate"
    region = "us-east-1"
  }
}
