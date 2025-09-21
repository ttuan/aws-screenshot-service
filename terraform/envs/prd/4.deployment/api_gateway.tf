###################
# API Gateway REST API
###################

resource "aws_api_gateway_rest_api" "screenshot_api" {
  name = "${var.project}-${var.env}-api"

  tags = {
    Name        = "${var.project}-${var.env}-api"
    Environment = var.env
  }
}

###################
# API Gateway Resources & Methods
###################

# /api resource
resource "aws_api_gateway_resource" "api" {
  rest_api_id = aws_api_gateway_rest_api.screenshot_api.id
  parent_id   = aws_api_gateway_rest_api.screenshot_api.root_resource_id
  path_part   = "api"
}

# /api/screenshot resource
resource "aws_api_gateway_resource" "screenshot" {
  rest_api_id = aws_api_gateway_rest_api.screenshot_api.id
  parent_id   = aws_api_gateway_resource.api.id
  path_part   = "screenshot"
}

# POST /api/screenshot
resource "aws_api_gateway_method" "screenshot_post" {
  rest_api_id   = aws_api_gateway_rest_api.screenshot_api.id
  resource_id   = aws_api_gateway_resource.screenshot.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "screenshot_post" {
  rest_api_id             = aws_api_gateway_rest_api.screenshot_api.id
  resource_id             = aws_api_gateway_resource.screenshot.id
  http_method             = aws_api_gateway_method.screenshot_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.screenshot_validator.invoke_arn
}

###################
# Lambda Permission
###################

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.screenshot_validator.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.screenshot_api.execution_arn}/*/*"
}

###################
# API Gateway Deployment
###################

resource "aws_api_gateway_deployment" "screenshot_api" {
  depends_on  = [aws_api_gateway_integration.screenshot_post]
  rest_api_id = aws_api_gateway_rest_api.screenshot_api.id
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.screenshot_api.id
  rest_api_id   = aws_api_gateway_rest_api.screenshot_api.id
  stage_name    = "prod"
}