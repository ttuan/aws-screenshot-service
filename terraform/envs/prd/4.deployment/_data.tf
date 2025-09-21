###################
# Data Sources
###################

# Reference general infrastructure
data "terraform_remote_state" "general" {
  backend = "s3"
  config = {
    bucket  = "screenshot-service-prd-iac-state"
    key     = "1.general/terraform.prd.tfstate"
    region  = "us-east-1"
    profile = "screenshot-service-prd"
  }
}

# Reference database resources
data "terraform_remote_state" "database" {
  backend = "s3"
  config = {
    bucket  = "screenshot-service-prd-iac-state"
    key     = "3.database/terraform.prd.tfstate"
    region  = "us-east-1"
    profile = "screenshot-service-prd"
  }
}

# Reference backend resources
data "terraform_remote_state" "backend" {
  backend = "s3"
  config = {
    bucket  = "screenshot-service-prd-iac-state"
    key     = "6.backend/terraform.prd.tfstate"
    region  = "us-east-1"
    profile = "screenshot-service-prd"
  }
}