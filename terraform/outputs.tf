output "image_public_url" {
  value       = "https://${aws_cloudfront_distribution.images.domain_name}/${var.image_filename}"
  description = "HTTPS URL to use in Auth0 for the hosted image."
}

output "image_s3_bucket" {
  value       = aws_s3_bucket.images.bucket
  description = "S3 bucket name — upload your image here after apply."
}

output "next_steps" {
  value       = <<-EOT
    Bootstrap sequence:

    Apply 1 (AWS Org + SSO baseline):
      terraform apply -target=aws_organizations_organization.main
      terraform apply -target=aws_ssoadmin_permission_set.admin -target=aws_ssoadmin_managed_policy_attachment.admin

      Then go to: AWS Console → IAM Identity Center → Settings
      Copy the ACS URL and Issuer URL into terraform.tfvars as:
        sso_saml_acs_url  = "<acs url>"
        sso_saml_audience = "<issuer url>"

    Apply 2 (Auth0 SAML app + Google connection):
      terraform apply -target=auth0_client.aws_saml -target=auth0_connection.google -target=auth0_connection_clients.google_on_aws

      Note the auth0_saml_metadata_url output.

    Manual step (one-time, provider gap):
      AWS Console → IAM Identity Center → Settings → Change identity source → External IdP
      Paste the auth0_saml_metadata_url as the IdP metadata URL.
      — OR —
      aws sso-admin put-identity-provider-configuration \
        --instance-arn "$(terraform output -raw sso_instance_arn)" \
        --identity-provider-url "$(terraform output -raw auth0_saml_metadata_url)" \
        --region ${var.aws_region}

    Apply 3 (user assignment — after first Google login):
      Uncomment the data + resource blocks in aws_sso.tf, then:
      terraform apply
  EOT
  description = "Step-by-step guide to complete the bootstrap sequence."
}
