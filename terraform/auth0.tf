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

# --- Guard: only my_gmail_address may complete SSO into AWS ---
# The Google connection itself accepts *any* Google account — scoping it to
# the aws_saml client (above) restricts which app can use it, not who can log
# into that app. IAM Identity Center's own "don't auto-provision users"
# setting (toggled by hand during the manual activation step — see README) is
# one backstop against a stranger's login actually granting AWS access, but
# it's a console setting this repo doesn't manage or verify. This Action is a
# second, Terraform-managed guard that denies the SAML assertion outright for
# anyone but the account owner, so someone following the README isn't
# depending on remembering that unrelated setting to stay safe.
resource "auth0_action" "restrict_to_owner" {
  name    = "restrict-google-login-to-owner"
  runtime = "node18"
  deploy  = true

  code = <<-EOT
    exports.onExecutePostLogin = async (event, api) => {
      // Only guard the AWS SSO app — leave any other Auth0 app/connection alone.
      if (event.client.client_id !== event.secrets.AWS_SAML_CLIENT_ID) {
        return;
      }
      if (event.user.email !== event.secrets.ALLOWED_EMAIL || !event.user.email_verified) {
        api.access.deny("unauthorized_email", "This account is not permitted to sign in.");
      }
    };
  EOT

  secrets {
    name  = "ALLOWED_EMAIL"
    value = var.my_gmail_address
  }
  secrets {
    name  = "AWS_SAML_CLIENT_ID"
    value = auth0_client.aws_saml.client_id
  }

  supported_triggers {
    id      = "post-login"
    version = "v3"
  }
}

resource "auth0_trigger_action" "restrict_to_owner" {
  trigger   = "post-login"
  action_id = auth0_action.restrict_to_owner.id
}

output "auth0_saml_metadata_url" {
  value       = "https://${var.auth0_domain}/samlp/metadata/${auth0_client.aws_saml.client_id}"
  description = "Paste this URL into IAM Identity Center as the external IdP metadata URL."
}

output "auth0_saml_login_url" {
  value       = "https://${var.auth0_domain}/samlp/${auth0_client.aws_saml.client_id}"
  description = "IdP-initiated SSO URL (if needed)."
}
