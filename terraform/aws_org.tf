resource "aws_organizations_organization" "main" {
  aws_service_access_principals = ["sso.amazonaws.com"]
  feature_set                   = "ALL"
  enabled_policy_types          = ["SERVICE_CONTROL_POLICY"]
}

# IAM Identity Center must be enabled once manually in the AWS console before
# this data source will resolve. After that one-time click, Terraform manages everything.
data "aws_ssoadmin_instances" "main" {
  depends_on = [aws_organizations_organization.main]
}

locals {
  sso_instance_arn      = tolist(data.aws_ssoadmin_instances.main.arns)[0]
  sso_identity_store_id = tolist(data.aws_ssoadmin_instances.main.identity_store_ids)[0]
}

output "sso_instance_arn" {
  value       = local.sso_instance_arn
  description = "IAM Identity Center instance ARN."
}
