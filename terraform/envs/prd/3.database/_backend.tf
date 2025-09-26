terraform {
  backend "s3" {
    profile        = "screenshot-service-prd"
    bucket         = "screenshot-service-prd-iac-state"
    key            = "3.database/terraform.prd.tfstate"
    region         = "us-east-1"
    encrypt        = true
    kms_key_id     = "alias/screenshot-service-prd-iac"
    dynamodb_table = "screenshot-service-prd-terraform-state-lock"
  }
}
