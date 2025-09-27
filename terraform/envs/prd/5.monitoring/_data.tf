# Get KMS key from general module
data "terraform_remote_state" "general" {
  backend = "s3"
  config = {
    bucket = "screenshot-service-prd-iac-state"
    key    = "1.general/terraform.prd.tfstate"
    region = "us-east-1"
  }
}
