# GCP resources are only needed if you want to use your own OAuth 2.0 client
# instead of Auth0's shared dev keys (Option B).
#
# The hashicorp/google provider does not have a resource for creating generic
# OAuth 2.0 Web Client credentials. Steps to do it manually in GCP console:
#
#   1. Create or select a GCP project
#   2. APIs & Services -> OAuth consent screen (External; add your Gmail as test user)
#   3. APIs & Services -> Credentials -> Create OAuth Client ID
#      - Application type: Web application
#      - Authorized redirect URI: https://<your-auth0-domain>.auth0.com/login/callback
#   4. Copy client ID + secret into .envrc as TF_VAR_google_oauth_client_id / _secret
#
# Uncomment the google provider in providers.tf and the resource blocks below
# when you're ready to manage GCP API enablement via Terraform.

# resource "google_project_service" "identity_api" {
#   project            = var.gcp_project_id
#   service            = "identitytoolkit.googleapis.com"
#   disable_on_destroy = false
# }
#
# resource "google_project_service" "oauth2_api" {
#   project            = var.gcp_project_id
#   service            = "oauth2.googleapis.com"
#   disable_on_destroy = false
# }
