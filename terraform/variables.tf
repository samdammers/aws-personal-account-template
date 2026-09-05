variable "image_filename" {
  type        = string
  default     = "logo.png"
  description = "S3 object key for the hosted image (e.g. logo.png). Upload this file to the S3 bucket after apply."
}

variable "aws_region" {
  type        = string
  description = "AWS region where IAM Identity Center is homed."
}

variable "aws_account_id" {
  type        = string
  description = "Your personal AWS account ID (12 digits)."
}

variable "owner_email" {
  type        = string
  description = "The account owner's email - used as the AWS security contact, the identity assigned PersonalAdmin, and the address both login guards check against. Doesn't have to be a Gmail address: it's whatever email is tied to your Google account (Google accounts can be linked to any address), or - if you're using the optional database connection instead - whatever email you sign in with there."
}

variable "enable_database_connection" {
  type        = bool
  default     = false
  description = "Optional: create an Auth0 database connection (plain email/password sign-in, no Google account needed) alongside Google login. Terraform generates a throwaway initial password to satisfy Auth0's user-creation requirement - it's never your real password and isn't meant to be. After applying, trigger a password-reset email for owner_email from the Auth0 dashboard (User Management -> Users -> your user -> Reset Password) so you set your actual password directly through Auth0, which Terraform/state never sees."
}

# Auth0
variable "auth0_domain" {
  type        = string
  description = "Auth0 tenant domain, e.g. myapp.us.auth0.com"
}

variable "auth0_management_client_id" {
  type        = string
  description = "Client ID of the Auth0 Machine-to-Machine app with Management API access."
}

variable "auth0_management_client_secret" {
  type        = string
  sensitive   = true
  description = "Client secret of the Auth0 Management API M2M app."
}

# Set after Apply 1: copy from IAM Identity Center SAML metadata
variable "sso_saml_acs_url" {
  type        = string
  default     = ""
  description = "ACS URL from IAM Identity Center SAML metadata. Populated after Apply 1."
}

variable "sso_saml_audience" {
  type        = string
  default     = ""
  description = "Issuer/Audience URL from IAM Identity Center SAML metadata. Populated after Apply 1."
}

variable "account_owner_phone" {
  type        = string
  description = "Phone number for the AWS account security contact (e.g. +61400000000)."
}

variable "repo_tag" {
  type        = string
  default     = "samdammers/aws-personal-account-template"
  description = "Value for the Repo default tag applied to every resource this stack creates - override if you forked/renamed this repo."
}
