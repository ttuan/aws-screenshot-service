###################
# Security Groups for ECS Tasks
###################

# Security group for ECS tasks
resource "aws_security_group" "ecs_tasks" {
  name_prefix = "${var.project}-${var.env}-ecs-tasks-"
  vpc_id      = data.terraform_remote_state.general.outputs.vpc_id
  description = "Security group for ECS screenshot processing tasks"

  # Outbound rules for AWS services
  egress {
    description = "HTTPS to AWS services"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP outbound for potential web scraping/screenshot generation
  egress {
    description = "HTTP outbound"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # DNS resolution
  egress {
    description = "DNS resolution"
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.env}-ecs-tasks-sg"
    Environment = var.env
    Project     = var.project
    Service     = "screenshot-processing"
    Terraform   = "true"
  }

  lifecycle {
    create_before_destroy = true
  }
}
