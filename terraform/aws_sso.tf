resource "aws_ssoadmin_permission_set" "admin" {
  name             = "PersonalAdmin"
  instance_arn     = local.sso_instance_arn
  session_duration = "PT8H"
  description      = "Full admin access for personal account owner."
}

resource "aws_ssoadmin_managed_policy_attachment" "admin" {
  instance_arn       = local.sso_instance_arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
}

data "aws_identitystore_user" "me" {
  identity_store_id = local.sso_identity_store_id
  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = var.owner_email
    }
  }
}

resource "aws_ssoadmin_account_assignment" "me" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
  principal_id       = data.aws_identitystore_user.me.user_id
  principal_type     = "USER"
  target_id          = var.aws_account_id
  target_type        = "AWS_ACCOUNT"
}
