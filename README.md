# AWS Screenshot Service

> Node.js microservice for capturing website screenshots using Puppeteer (headless Chrome). Production-ready with AWS integration for scalable deployment.

## 📋 Table of Contents

- [Architecture Overview](#-architecture-overview)
- [Prerequisites](#-prerequisites)
- [Installation & Setup](#-installation--setup)
- [Project Structure](#-project-structure)
- [Configuration](#-configuration)
- [Deployment](#-deployment)
- [Service Management](#-service-management)
- [Testing](#-testing)
- [Monitoring](#-monitoring)
- [Troubleshooting](#-troubleshooting)
- [Contributing](#-contributing)

## 🏗️ Architecture Overview

The AWS Screenshot Service implements a serverless, event-driven architecture for scalable website screenshot capture:

```
Client Request → API Gateway → Lambda Functions → SQS → ECS Fargate → S3/DynamoDB
```

### Core Components

| Component | Purpose | Technology |
|-----------|---------|------------|
| **API Gateway** | RESTful endpoint with throttling & validation | AWS API Gateway |
| **Lambda Functions** | URL validation & job status checking | Node.js 22.x |
| **SQS Queues** | Asynchronous job processing | AWS SQS |
| **ECS Fargate** | Screenshot processing with Puppeteer | Docker + Node.js |
| **DynamoDB** | Job status and metadata storage | AWS DynamoDB |
| **S3** | Screenshot image storage | AWS S3 |
| **CloudWatch** | Monitoring, logging, and alerting | AWS CloudWatch |

### Available Environments

- **STG** (`ap-northeast-1`): Staging environment for testing
- **PRD** (`us-east-1`): Production environment

## 🔧 Prerequisites

### Required Tools

1. **AWS CLI** - [Installation Guide](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
2. **Terraform** - [Installation Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli)
3. **Make** - Usually pre-installed on Unix systems
4. **jq** - For JSON processing in scripts

### AWS Account Setup

1. **IAM User Creation**
   - Create IAM user with programmatic access
   - Attach necessary permissions for Terraform operations
   - Enable MFA for enhanced security

2. **AWS Profile Configuration**
   ```bash
   # For environments without MFA
   aws configure --profile screenshot-service-prd
   aws configure --profile screenshot-service-stg

   # For environments with MFA (recommended)
   aws configure --profile screenshot-service-default
   ```

3. **MFA Configuration** (Optional but recommended)
   ```bash
   # Add MFA profiles to ~/.aws/credentials
   [screenshot-service-prd]
   aws_access_key_id =
   aws_secret_access_key =
   aws_session_token =
   ```

## 🚀 Installation & Setup

### 1. Initial Infrastructure Setup

Before deploying Terraform resources, create the required backend infrastructure:

```bash
# Run the automated setup script
./pre-build.sh
```

**Manual Setup** (if preferred):
```bash
# Set environment variables
export PROJECT="screenshot-service"
export ENV="prd"  # or "stg"
export REGION="us-east-1"  # or "ap-northeast-1" for staging

# Create S3 bucket for Terraform state
aws s3api create-bucket --bucket $PROJECT-$ENV-iac-state --region $REGION --profile $PROJECT-$ENV

# Create DynamoDB table for state locking
aws dynamodb create-table \
    --table-name $PROJECT-$ENV-terraform-state-lock \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION \
    --profile $PROJECT-$ENV

# Create KMS key for encryption
KMS_KEY_ID=$(aws kms create-key --description "Encrypt tfstate in s3 backend" \
    --query "KeyMetadata.KeyId" --output text --profile $PROJECT-$ENV --region $REGION)
aws kms create-alias --alias-name alias/$PROJECT-$ENV-iac \
    --target-key-id $KMS_KEY_ID --profile $PROJECT-$ENV --region $REGION
```

### 2. MFA Token Generation

If using MFA (recommended for production):

```bash
./create-aws-sts.sh screenshot-service-default screenshot-service-prd ACCOUNT_ID IAM_USER_NAME TOKEN_CODE
```

### 3. Environment Variables

Configure your environment variables in the respective `.tfvars` files:

- `terraform/envs/prd/terraform.prd.tfvars`
- `terraform/envs/stg/terraform.stg.tfvars`

## 📁 Project Structure

```
aws-screenshot-service/
├── terraform/
│   ├── envs/
│   │   ├── prd/                    # Production environment
│   │   │   ├── 1.general/          # VPC, IAM, S3 foundation
│   │   │   ├── 2.admin/            # Administrative resources
│   │   │   ├── 3.database/         # DynamoDB tables
│   │   │   ├── 4.deployment/       # Lambda, API Gateway
│   │   │   ├── 5.monitoring/       # CloudWatch, alarms
│   │   │   ├── 6.backend/          # ECS, SQS, auto-scaling
│   │   │   └── terraform.prd.tfvars
│   │   └── stg/                    # Staging environment
│   │       └── terraform.stg.tfvars
│   └── README.md
├── terraform-dependencies/        # CodeBuild/CodeDeploy configs
├── scripts/
│   ├── create-aws-sts.sh          # MFA token generation
│   ├── pre-build.sh               # Infrastructure bootstrap
│   └── test-screenshot-requests.sh # Load testing script
├── Makefile                       # Automation commands
└── README.md
```

### Service Deployment Order

Services must be deployed in the following order due to dependencies:

1. **1.general** - VPC, IAM roles, S3 buckets
2. **2.admin** - Administrative resources
3. **3.database** - DynamoDB tables
4. **4.deployment** - Lambda functions, API Gateway
5. **5.monitoring** - CloudWatch resources
6. **6.backend** - ECS cluster, SQS queues, auto-scaling

## ⚙️ Configuration

### Environment Configuration

Edit the environment-specific variables:

```bash
# Production
vim terraform/envs/prd/terraform.prd.tfvars

# Staging
vim terraform/envs/stg/terraform.stg.tfvars
```

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `project` | Project name | `screenshot-service` |
| `env` | Environment name | `prd` or `stg` |
| `region` | AWS region | `us-east-1` |
| `container_image_uri` | ECS container image | `123456789.dkr.ecr.us-east-1.amazonaws.com/screenshot-service:latest` |

## 🚢 Deployment

### Quick Deployment (All Services)

```bash
# Deploy all services to production
make symlink_all e=prd
make init_all e=prd
make plan_all e=prd
make apply_all e=prd

# Deploy all services to staging
make symlink_all e=stg
make init_all e=stg
make plan_all e=stg
make apply_all e=stg
```

### Individual Service Deployment

```bash
# Deploy a specific service
make symlink e=prd s=general
make init e=prd s=general
make plan e=prd s=general
make apply e=prd s=general
```

## 🛠️ Service Management


### Editing an Existing Service

1. **Make Changes** to the Terraform files
2. **Plan Changes**
   ```bash
   make plan e=prd s=existing.service
   ```
3. **Apply Changes**
   ```bash
   make apply e=prd s=existing.service
   ```

### Removing a Service

1. **Destroy Resources**
   ```bash
   make destroy e=prd s=service.name
   ```

2. **Remove Symlinks**
   ```bash
   make unsymlink e=prd s=service.name
   ```

3. **Clean Up Directory**
   ```bash
   rm -rf terraform/envs/prd/service.name/
   ```

## 🧪 Testing

### Load Testing

Use the provided script to test the screenshot service:

```bash
# Test with default settings (150 requests)
./test-screenshot-requests.sh

# Edit the script to customize:
# - API_ENDPOINT: Your API Gateway endpoint
# - TOTAL_REQUESTS: Number of requests to send
# - Test URLs and viewport dimensions
```

### Manual Testing

```bash
# Test screenshot request
curl -X POST "https://your-api-gateway-url/prod/api/screenshot" \
  -H "Content-Type: application/json" \
  -d '{
    "url": "https://example.com",
    "options": {
      "width": 1200,
      "height": 800,
      "fullPage": true
    }
  }'

# Check job status
curl "https://your-api-gateway-url/prod/api/status/YOUR-JOB-ID"
```

## 📊 Monitoring

### CloudWatch Dashboards

The service includes comprehensive monitoring through CloudWatch:

- **API Gateway Metrics**: Request count, latency, errors
- **Lambda Metrics**: Invocations, duration, errors
- **SQS Metrics**: Queue depth, message age
- **ECS Metrics**: CPU, memory utilization
- **Custom Alarms**: Auto-scaling triggers

### Key Metrics to Monitor

1. **SQS Queue Depth** - Triggers ECS auto-scaling
2. **ECS Task Count** - Scaling activity
3. **Lambda Error Rate** - Function health
4. **API Gateway 4xx/5xx Errors** - Client/server errors
5. **S3 Storage Usage** - Storage costs

### Accessing Logs

```bash
# View Lambda logs
aws logs describe-log-groups --profile screenshot-service-prd

# View ECS logs
aws logs describe-log-groups --log-group-name-prefix "/ecs/screenshot-service" --profile screenshot-service-prd
```

## 🔧 Troubleshooting

### Common Issues

1. **State Lock Issues**
   ```bash
   # Force unlock if needed (use carefully)
   terraform force-unlock LOCK_ID -chdir=terraform/envs/prd/service.name/
   ```

2. **Permission Errors**
   ```bash
   # Refresh MFA token
   ./create-aws-sts.sh screenshot-service-default screenshot-service-prd ACCOUNT_ID IAM_USER_NAME NEW_TOKEN
   ```

3. **Resource Dependencies**
   ```bash
   # Check dependency order and deploy services in sequence
   make plan e=prd s=general  # Deploy foundation first
   make plan e=prd s=backend  # Deploy backend services last
   ```

4. **ECS Task Failures**
   ```bash
   # Check ECS service events
   aws ecs describe-services --cluster screenshot-service-prd-cluster --services screenshot-service-prd-service --profile screenshot-service-prd

   # Check task logs
   aws logs filter-log-events --log-group-name /ecs/screenshot-service-prd --profile screenshot-service-prd
   ```

### Debugging Commands

```bash
# Validate Terraform configuration
terraform validate -chdir=terraform/envs/prd/service.name/

# Format Terraform files
terraform fmt -recursive terraform/

# Show Terraform plan in detail
make plan e=prd s=service.name | tee plan.out
```

## 🤝 Contributing

### Development Workflow

1. **Create Feature Branch**
   ```bash
   git checkout -b feature/new-feature
   ```

2. **Make Changes** following the project structure

3. **Test Changes**
   ```bash
   make plan e=stg s=affected.service
   ```

4. **Submit Pull Request** with detailed description

### Code Standards

- Follow Terraform naming conventions
- Use consistent resource tagging
- Document all variables and outputs
- Test in staging before production deployment


## 📞 Support

For issues and questions:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Review CloudWatch logs and metrics
3. Contact the DevOps team
