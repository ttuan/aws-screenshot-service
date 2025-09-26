###################
# WAF Web ACL for API Gateway
###################

resource "aws_wafv2_web_acl" "screenshot_api_waf" {
  name  = "${var.project}-${var.env}-api-waf"
  scope = "REGIONAL"

  default_action {
    allow {}
  }

  # Rate limiting rule - Block IPs making too many requests
  rule {
    name     = "RateLimitRule"
    priority = 1

    statement {
      rate_based_statement {
        limit              = 100 # 100 requests per 5 minutes per IP
        aggregate_key_type = "IP"
      }
    }

    action {
      block {}
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRule"
    }
  }

  # Request size limit rule
  rule {
    name     = "RequestSizeRule"
    priority = 2

    statement {
      size_constraint_statement {
        field_to_match {
          body {}
        }
        comparison_operator = "GT"
        size                = 8192 # 8KB max request body
        text_transformation {
          priority = 1
          type     = "NONE"
        }
      }
    }

    action {
      block {}
    }

    visibility_config {
      sampled_requests_enabled   = true
      cloudwatch_metrics_enabled = true
      metric_name                = "RequestSizeRule"
    }
  }

  tags = {
    Name        = "${var.project}-${var.env}-api-waf"
    Environment = var.env
  }

  visibility_config {
    sampled_requests_enabled   = true
    cloudwatch_metrics_enabled = true
    metric_name                = "ScreenshotAPIWAF"
  }
}

###################
# WAF Association with API Gateway
###################

resource "aws_wafv2_web_acl_association" "screenshot_api_waf_association" {
  resource_arn = aws_api_gateway_stage.prod.arn
  web_acl_arn  = aws_wafv2_web_acl.screenshot_api_waf.arn
}
