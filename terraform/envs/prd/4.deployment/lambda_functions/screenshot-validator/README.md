# Screenshot Validator Lambda Function

A Node.js AWS Lambda function that validates screenshot requests and queues them for processing via SQS.

## Overview

This Lambda function serves as a validation gateway for screenshot requests. It validates incoming URLs against security and format rules, then forwards valid requests to an SQS queue for processing by screenshot workers.

## Features

- **URL Validation**: Comprehensive URL validation with security checks
- **CORS Support**: Pre-configured CORS headers for web client integration
- **Security Hardening**: Blocks localhost, private IPs, and cloud metadata services
- **SQS Integration**: Forwards validated requests to SQS queue
- **Error Handling**: Detailed error responses with debugging information

## Architecture

```
Client Request → API Gateway → Lambda Function → SQS Queue → Screenshot Worker
```

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SQS_QUEUE_URL` | SQS queue URL for screenshot requests | `https://sqs.us-east-1.amazonaws.com/123456789/screenshot-queue` |
| `NODE_ENV` | Environment (production/development) | `production` |
| `AWS_REGION` | AWS region for SQS client | `us-east-1` |

## API Endpoints

### POST /screenshot

Validates and queues a screenshot request.

**Request Body:**
```json
{
  "url": "https://example.com",
  "options": {
    "width": 1200,
    "height": 800,
    "fullPage": true
  }
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Screenshot request queued successfully",
  "requestId": "abc-123-def"
}
```

**Error Response (400):**
```json
{
  "success": false,
  "error": "URL must use HTTP or HTTPS protocol"
}
```

### OPTIONS /screenshot

CORS preflight support for web clients.

## URL Validation Rules

- Must be a non-empty string
- Maximum length: 2048 characters
- Must use HTTP or HTTPS protocol
- Must have a valid hostname with TLD
- **Production restrictions:**
  - Blocks localhost (`127.0.0.1`, `localhost`, `::1`)
  - Blocks private IP ranges
  - Blocks cloud metadata services (`169.254.169.254`)

## Dependencies

- `@aws-sdk/client-sqs`: AWS SQS client for Node.js

## Development

### Local Setup

1. Install dependencies:
```bash
npm install
```

2. Set environment variables in `env.json`:
```json
{
  "Variables": {
    "SQS_QUEUE_URL": "your-sqs-queue-url",
    "NODE_ENV": "development"
  }
}
```

### Testing Locally

You can test the function locally using the AWS CLI:

```bash
aws lambda invoke \
  --function-name screenshot-validator \
  --payload '{"httpMethod":"POST","body":"{\"url\":\"https://example.com\"}"}' \
  response.json && cat response.json
```

## Deployment

### Prerequisites

- AWS CLI configured with appropriate permissions
- Lambda function already created in AWS

### Quick Deployment Commands

1. **Package and deploy** (run from this directory):
```bash
# Create deployment package
zip -r screenshot-validator.zip . -x "*.git*" "README.md" "*.md"

# Deploy to AWS Lambda
aws lambda update-function-code \
  --function-name screenshot-validator \
  --zip-file fileb://screenshot-validator.zip

# Verify deployment
aws lambda get-function \
  --function-name screenshot-validator \
  --query 'Configuration.{Status:State,LastUpdate:LastUpdateStatus,Modified:LastModified}'
```

2. **One-line deployment** (for frequent updates):
```bash
zip -r screenshot-validator.zip . -x "*.git*" "README.md" "*.md" && aws lambda update-function-code --function-name screenshot-validator --zip-file fileb://screenshot-validator.zip
```

3. **Update environment variables** (if needed):
```bash
aws lambda update-function-configuration \
  --function-name screenshot-validator \
  --environment file://env.json
```

### Deployment Script

Create `deploy.sh` for easier deployment:

```bash
#!/bin/bash
set -e

echo "📦 Creating deployment package..."
zip -r screenshot-validator.zip . -x "*.git*" "README.md" "*.md" "deploy.sh"

echo "🚀 Deploying to AWS Lambda..."
aws lambda update-function-code \
  --function-name screenshot-validator \
  --zip-file fileb://screenshot-validator.zip

echo "✅ Verifying deployment..."
aws lambda get-function \
  --function-name screenshot-validator \
  --query 'Configuration.{Status:State,LastUpdate:LastUpdateStatus,Modified:LastModified}' \
  --output table

echo "🎉 Deployment complete!"
```

Make it executable: `chmod +x deploy.sh`

## Monitoring

### CloudWatch Logs

Monitor function execution:
```bash
aws logs tail /aws/lambda/screenshot-validator --follow
```

### Function Metrics

Check function performance:
```bash
aws lambda get-function \
  --function-name screenshot-validator \
  --query 'Configuration.{Timeout:Timeout,Memory:MemorySize,Runtime:Runtime}'
```

## Troubleshooting

### Common Issues

1. **SQS Permissions**: Ensure Lambda execution role has `sqs:SendMessage` permission
2. **CORS Errors**: Check that CORS headers are properly configured
3. **Timeout Issues**: Increase function timeout if processing takes longer
4. **Memory Issues**: Monitor memory usage and increase if needed

### Debug Mode

For debugging, you can enable detailed logging by checking the function logs:

```bash
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/screenshot-validator"
```

## Security Considerations

- Function validates and sanitizes all input URLs
- Blocks access to internal/private networks
- Uses least-privilege IAM permissions
- All errors are logged for security monitoring

## License

Private use only.
