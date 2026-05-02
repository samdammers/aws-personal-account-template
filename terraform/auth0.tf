resource "auth0_connection" "google" {
  name     = "google-oauth2"
  strategy = "google-oauth2"

  options {
    # Leave client_id/client_secret empty to use Auth0's shared dev keys.
    # For production, supply your own GCP OAuth 2.0 client credentials.
    client_id     = var.google_oauth_client_id != "" ? var.google_oauth_client_id : null
    client_secret = var.google_oauth_client_secret != "" ? var.google_oauth_client_secret : null
    scopes        = ["email", "profile"]
  }
}

resource "auth0_client" "aws_saml" {
  name      = "AWS IAM Identity Center"
  app_type  = "regular_web"
  callbacks = [var.sso_saml_acs_url]
  logo_uri  = "https://${aws_cloudfront_distribution.images.domain_name}/${var.image_filename}"

  addons {
    samlp {
      # Populated from IAM Identity Center SAML metadata after Apply 1.
      audience  = var.sso_saml_audience
      recipient = var.sso_saml_acs_url

      name_identifier_format = "urn:oasis:names:tc:SAML:1.1:nameid-format:emailAddress"
      name_identifier_probes = ["email"]

      mappings = {
        "email"       = "email"
        "name"        = "name"
        "given_name"  = "given_name"
        "family_name" = "family_name"
      }

      sign_response       = true
      lifetime_in_seconds = 3600
      signature_algorithm = "rsa-sha256"
      digest_algorithm    = "sha256"
    }
  }
}

# Enable Google connection on the AWS SAML app only
resource "auth0_connection_clients" "google_on_aws" {
  connection_id   = auth0_connection.google.id
  enabled_clients = [auth0_client.aws_saml.client_id]
}

output "auth0_saml_metadata_url" {
  value       = "https://${var.auth0_domain}/samlp/metadata/${auth0_client.aws_saml.client_id}"
  description = "Paste this URL into IAM Identity Center as the external IdP metadata URL."
}

output "auth0_saml_login_url" {
  value       = "https://${var.auth0_domain}/samlp/${auth0_client.aws_saml.client_id}"
  description = "IdP-initiated SSO URL (if needed)."
}
