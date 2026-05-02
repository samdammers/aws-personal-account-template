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

variable "my_gmail_address" {
  type        = string
  description = "The Gmail address used to sign in to AWS."
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

# GCP OAuth client — leave blank to use Auth0 dev keys (fine for personal use)
# Add the hashicorp/google provider back to providers.tf when you need these.
variable "gcp_project_id" {
  type        = string
  default     = ""
  description = "GCP project ID. Only needed if creating your own OAuth client (Option B)."
}

variable "google_oauth_client_id" {
  type        = string
  default     = ""
  description = "GCP OAuth 2.0 client ID for Auth0 Google connection. Leave blank to use Auth0 dev keys."
}

variable "google_oauth_client_secret" {
  type        = string
  sensitive   = true
  default     = ""
  description = "GCP OAuth 2.0 client secret. Leave blank to use Auth0 dev keys."
}

variable "account_owner_phone" {
  type        = string
  description = "Phone number for the AWS account security contact (e.g. +61400000000)."
}
