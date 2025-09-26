project = "screenshot-service"
env     = "prd"
region  = "us-east-1"

# Container image URI for ECS Fargate service
# Container image URI will be dynamically constructed using data.aws_caller_identity
# container_image_uri = "534929761277.dkr.ecr.us-east-1.amazonaws.com/screenshot-service-prd:latest"
container_image_tag = "latest"

# Optional: Set email for alerts and budget notifications
alert_email = "tran.van.tuan@sun-asterisk.com"

# Optional: Customize budget limits (defaults: monthly=20, daily=5, ecs=10)
monthly_budget_limit = 10
daily_budget_limit   = 1
ecs_budget_limit     = 5
