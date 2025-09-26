# general

All general AWS resources of project

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.9 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0 |
| <a name="requirement_template"></a> [template](#requirement\_template) | ~> 2.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 4.56.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_iam_role_lambda_example"></a> [iam\_role\_lambda\_example](#module\_iam\_role\_lambda\_example) | git@github.com:framgia/sun-infra-iac.git//modules/iam-role | terraform-aws-iam_v0.1.2 |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | git@github.com:framgia/sun-infra-iac.git//modules/vpc | terraform-aws-vpc_v0.0.1 |

## Resources

| Name | Type |
|------|------|
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.assume_role_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

No inputs.

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_account_id"></a> [aws\_account\_id](#output\_aws\_account\_id) | Show information about project, environment and account |
| <a name="output_iam_role_lambda_example_arn"></a> [iam\_role\_lambda\_example\_arn](#output\_iam\_role\_lambda\_example\_arn) | ARN of IAM Role Lambda Example |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | ID of VPC |
<!-- END_TF_DOCS -->
