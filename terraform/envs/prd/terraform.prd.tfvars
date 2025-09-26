project = "screenshot-service"
env     = "prd"
region  = "us-east-1"

# Container image URI for ECS Fargate service
# Container image URI will be dynamically constructed using data.aws_caller_identity
# container_image_uri = "534929761277.dkr.ecr.us-east-1.amazonaws.com/screenshot-service-prd:latest"
container_image_tag = "latest"
