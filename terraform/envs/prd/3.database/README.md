# 3.database

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.13.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.14.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.14.1 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_dynamodb_table.screenshot_jobs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alert_email"></a> [alert\_email](#input\_alert\_email) | Email address for receiving alerts and budget notifications | `string` | `""` | no |
| <a name="input_container_image_tag"></a> [container\_image\_tag](#input\_container\_image\_tag) | Docker container image tag for the screenshot processing application | `string` | `"latest"` | no |
| <a name="input_daily_budget_limit"></a> [daily\_budget\_limit](#input\_daily\_budget\_limit) | Daily budget limit in USD | `number` | `5` | no |
| <a name="input_ecs_budget_limit"></a> [ecs\_budget\_limit](#input\_ecs\_budget\_limit) | ECS-specific monthly budget limit in USD | `number` | `10` | no |
| <a name="input_env"></a> [env](#input\_env) | Name of project environment | `string` | n/a | yes |
| <a name="input_monthly_budget_limit"></a> [monthly\_budget\_limit](#input\_monthly\_budget\_limit) | Monthly budget limit in USD | `number` | `20` | no |
| <a name="input_project"></a> [project](#input\_project) | Name of project | `string` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | Region of environment | `string` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dynamodb_table_name"></a> [dynamodb\_table\_name](#output\_dynamodb\_table\_name) | DynamoDB table name for Lambda environment variables |
| <a name="output_screenshot_jobs_table_arn"></a> [screenshot\_jobs\_table\_arn](#output\_screenshot\_jobs\_table\_arn) | ARN of the screenshot jobs DynamoDB table |
| <a name="output_screenshot_jobs_table_name"></a> [screenshot\_jobs\_table\_name](#output\_screenshot\_jobs\_table\_name) | Name of the screenshot jobs DynamoDB table |
<!-- END_TF_DOCS -->
