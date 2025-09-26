# 📊 Monitoring Module

Comprehensive monitoring and cost management for Screenshot Service.

## 🏗️ Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   CloudWatch    │    │   AWS Budgets    │    │  Cost Anomaly   │
│     Alarms      │───▶│   & Alerts       │───▶│   Detection     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                        │                       │
         ▼                        ▼                       ▼
┌─────────────────────────────────────────────────────────────────┐
│                     SNS Topic (Alerts)                         │
│                  ┌─────────────────────┐                       │
│                  │  Email (Optional)   │                       │
│                  │  Slack (Future)     │                       │
│                  │  PagerDuty (Future) │                       │
│                  └─────────────────────┘                       │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 Components

### 🔔 CloudWatch Alarms (8 alarms)
| Alarm | Metric | Threshold | Purpose |
|-------|--------|-----------|---------|
| High Queue Depth | SQS Messages | > 50 | Processing bottlenecks |
| DLQ Messages | DLQ Messages | > 0 | Failed requests |
| ECS High CPU | ECS CPU | > 80% | Performance issues |
| ECS High Memory | ECS Memory | > 85% | Memory pressure |
| No Running Tasks | ECS Tasks | < 1 | Service availability |
| Lambda Errors | Lambda Errors | > 5/5min | Function issues |
| Lambda Duration | Lambda Duration | > 25s | Near-timeout |
| Slow Processing | Screenshot Time | > 60s | Performance degradation |

### 💰 Cost Management
- **Monthly Budget**: $200 (configurable)
- **Daily Budget**: $10 (configurable)
- **ECS Budget**: $120 (configurable)
- **Cost Anomaly Detection**: AI-powered unusual spending alerts

### 📊 Dashboard
4-widget CloudWatch dashboard with:
- Screenshot processing time metrics
- SQS queue metrics (main + DLQ)
- ECS service utilization (CPU/Memory)
- Service health metrics (task count, Lambda invocations/errors)

## ⚙️ Configuration

### Basic Setup
```hcl
# terraform.prd.tfvars
project = "screenshot-service"
env     = "prd"
region  = "us-east-1"
```

### Email Notifications (Optional)
```hcl
# terraform.prd.tfvars
alert_email = "devops@yourcompany.com"
```

### Custom Budget Limits (Optional)
```hcl
# terraform.prd.tfvars
monthly_budget_limit = 300  # Default: 200
daily_budget_limit   = 15   # Default: 10
ecs_budget_limit     = 180  # Default: 120
```

## 🚀 Deployment

```bash
# Deploy monitoring
make apply e=prd s=monitoring

# View outputs
make output e=prd s=monitoring
```

## 📈 Accessing Monitoring

### CloudWatch Dashboard
```bash
# Dashboard URL available in outputs
terraform output dashboard_url
```

### SNS Topic
```bash
# SNS Topic ARN for integration
terraform output sns_alerts_topic_arn
```

### Budget Management
```bash
# View budget names and limits
terraform output budget_limits
```

## 🔧 Customization

### Adding More Notification Channels

1. **Slack Integration**:
```hcl
resource "aws_sns_topic_subscription" "slack_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"
}
```

2. **PagerDuty Integration**:
```hcl
resource "aws_sns_topic_subscription" "pagerduty_alerts" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "https"
  endpoint  = "https://events.pagerduty.com/integration/YOUR_INTEGRATION_KEY/enqueue"
}
```

### Advanced Configuration

For more dynamic configuration options, you can implement:
- AWS Parameter Store for centralized config
- AWS Secrets Manager for sensitive data
- External data sources for complex integrations

## 📊 Cost Breakdown

| Component | Monthly Cost | Notes |
|-----------|--------------|-------|
| CloudWatch Alarms | $3.60 | 8 alarms × $0.10 × 4 weeks |
| Enhanced Dashboard | $3.00 | Custom dashboard |
| SNS Notifications | $0.50 | Per 1M notifications |
| **Total** | **~$7/month** | Excellent ROI for 24/7 monitoring |

## 🚨 Alert Scenarios

### Critical Alerts
- ECS tasks all stopped
- DLQ has failed messages
- Daily budget exceeded
- Cost anomaly detected

### Warning Alerts
- High CPU/Memory usage
- Queue depth building up
- Monthly budget at 80%
- Lambda near timeout

## 🔍 Troubleshooting

### No Email Alerts
1. Check `alert_email` variable is set
2. Confirm email subscription in SNS console
3. Check spam folder for AWS confirmation email

### Missing Metrics
1. Verify ECS log group exists: `/ecs/screenshot-service-prd-screenshot-processor`
2. Check log metric filter pattern matches application logs
3. Ensure applications are writing logs in expected format

### Budget Alerts Not Working
1. Verify resources are tagged with `Project:screenshot-service`
2. Check budget notification settings in AWS Console
3. Ensure cost allocation tags are enabled

## 📚 References

- [AWS CloudWatch Alarms](https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/AlarmThatSendsEmail.html)
- [AWS Budgets](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/budgets-managing-costs.html)
- [Cost Anomaly Detection](https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/getting-started-ad.html)
