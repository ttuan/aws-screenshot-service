###################
# Create VPC and only one Nat Gateway for all AZs
###################
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project}-${var.env}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${var.region}a", "${var.region}b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

###################
# VPC Endpoints for Cost Optimization & Security
###################

# S3 Gateway Endpoint (FREE - no hourly charges)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name        = "${var.project}-${var.env}-s3-endpoint"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# DynamoDB Gateway Endpoint (FREE - no hourly charges)
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Name        = "${var.project}-${var.env}-dynamodb-endpoint"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# Security Group for Interface Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix = "${var.project}-${var.env}-vpc-endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.project}-${var.env}-vpc-endpoints-sg"
    Environment = var.env
    Project     = var.project
    Terraform   = "true"
  }
}

# ECR DKR Interface Endpoint (for Docker registry)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-${var.env}-ecr-dkr-endpoint"
    Environment = var.env
    Project     = var.project
    Service     = "ecr"
    Terraform   = "true"
  }
}

# ECR API Interface Endpoint (for ECR API calls)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-${var.env}-ecr-api-endpoint"
    Environment = var.env
    Project     = var.project
    Service     = "ecr"
    Terraform   = "true"
  }
}

# CloudWatch Logs Interface Endpoint
resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-${var.env}-logs-endpoint"
    Environment = var.env
    Project     = var.project
    Service     = "cloudwatch"
    Terraform   = "true"
  }
}

# ECS Interface Endpoint (for ECS API calls)
resource "aws_vpc_endpoint" "ecs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-${var.env}-ecs-endpoint"
    Environment = var.env
    Project     = var.project
    Service     = "ecs"
    Terraform   = "true"
  }
}

# ECS Agent Interface Endpoint (for ECS agent communication)
resource "aws_vpc_endpoint" "ecs_agent" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecs-agent"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-${var.env}-ecs-agent-endpoint"
    Environment = var.env
    Project     = var.project
    Service     = "ecs"
    Terraform   = "true"
  }
}

# ECS Telemetry Interface Endpoint (for ECS telemetry)
resource "aws_vpc_endpoint" "ecs_telemetry" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.region}.ecs-telemetry"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name        = "${var.project}-${var.env}-ecs-telemetry-endpoint"
    Environment = var.env
    Project     = var.project
    Service     = "ecs"
    Terraform   = "true"
  }
}
