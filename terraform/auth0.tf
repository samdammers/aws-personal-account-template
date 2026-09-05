resource "auth0_connection" "google" {
  name     = "google-oauth2"
  strategy = "google-oauth2"

  options {
    # Deliberately using Auth0's shared dev keys, not a dedicated GCP OAuth
    # client - see the README for the tradeoff.
    scopes = ["email", "profile"]
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

# --- Optional: plain email/password sign-in, no Google account needed ---
# Skipped (count = 0) unless enable_database_connection is set. disable_signup
# is reliably enforced for database connections (unlike the unconfirmed case
# for google-oauth2 below), so the only user that can ever exist here is the
# one auth0_user creates directly - no post-hoc guard needed.
resource "auth0_connection" "database" {
  count    = var.enable_database_connection ? 1 : 0
  name     = "owner-database"
  strategy = "auth0"

  options {
    disable_signup  = true
    password_policy = "good"
  }
}

resource "auth0_connection_clients" "database_on_aws" {
  count           = var.enable_database_connection ? 1 : 0
  connection_id   = auth0_connection.database[0].id
  enabled_clients = [auth0_client.aws_saml.client_id]
}

# Throwaway password, only to satisfy Auth0's creation requirement - see
# enable_database_connection's description for why, and the reset step to
# set a real one.
resource "random_password" "owner_database" {
  count            = var.enable_database_connection ? 1 : 0
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "auth0_user" "owner" {
  count           = var.enable_database_connection ? 1 : 0
  connection_name = auth0_connection.database[0].name
  email           = var.owner_email
  password        = random_password.owner_database[0].result
  email_verified  = true
}

# --- Guard: only owner_email may complete SSO into AWS ---
# Checks the authenticated email regardless of which connection was used
# (Google or the optional database one above). Scoping the Google connection
# to the aws_saml client (above) restricts which app can use it, not who can
# log into that app - this Action is what actually restricts who. IAM
# Identity Center's own "don't auto-provision users" setting (see README) is
# a second backstop on the AWS side, not a replacement for this.
resource "auth0_action" "restrict_to_owner" {
  name    = "restrict-login-to-owner"
  runtime = "node22"
  deploy  = true

  code = <<-EOT
    exports.onExecutePostLogin = async (event, api) => {
      // Only guard the AWS SSO app - leave any other Auth0 app/connection alone.
      if (event.client.client_id !== event.secrets.AWS_SAML_CLIENT_ID) {
        return;
      }
      // Case-insensitive: Google normalises the email claim to lowercase in
      // practice, but an exact-match comparison has zero slack for a typo'd
      // ALLOWED_EMAIL or an edge case in casing - this shouldn't be the thing
      // that locks the account owner out.
      if (event.user.email.toLowerCase() !== event.secrets.ALLOWED_EMAIL.toLowerCase() || !event.user.email_verified) {
        api.access.deny("unauthorized_email", "This account is not permitted to sign in.");
      }
    };
  EOT

  secrets {
    name  = "ALLOWED_EMAIL"
    value = var.owner_email
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

# --- Second guard, at registration time rather than login time ---
# The post-login guard above only stops a stranger from getting into AWS -
# Auth0 will still have created a user record for them by that point (social
# connections have no separate sign-up step to gate). This tries to stop
# that record from being created at all. Keyed to identity match rather than
# "does a user already exist," so the owner's own first-ever login is never
# at risk from this.
#
# Extra layer, not a replacement for the post-login guard: (1) unconfirmed
# whether this trigger fires for social connections at all - if not,
# harmless no-op; (2) unconfirmed whether `event.client` is populated the
# same way as in post-login, so the "just this app" scoping may be less
# precise - defensively checks it exists before reading `.client_id`.
resource "auth0_action" "restrict_to_owner_pre_registration" {
  name    = "restrict-registration-to-owner"
  runtime = "node22"
  deploy  = true

  code = <<-EOT
    exports.onExecutePreUserRegistration = async (event, api) => {
      if (event.client && event.client.client_id !== event.secrets.AWS_SAML_CLIENT_ID) {
        return;
      }
      if (event.user.email.toLowerCase() !== event.secrets.ALLOWED_EMAIL.toLowerCase()) {
        api.access.deny("unauthorized_email", "This account is not permitted to sign in.");
      }
    };
  EOT

  secrets {
    name  = "ALLOWED_EMAIL"
    value = var.owner_email
  }
  secrets {
    name  = "AWS_SAML_CLIENT_ID"
    value = auth0_client.aws_saml.client_id
  }

  supported_triggers {
    id      = "pre-user-registration"
    version = "v2"
  }
}

resource "auth0_trigger_action" "restrict_to_owner_pre_registration" {
  trigger   = "pre-user-registration"
  action_id = auth0_action.restrict_to_owner_pre_registration.id
}

output "auth0_saml_metadata_url" {
  value       = "https://${var.auth0_domain}/samlp/metadata/${auth0_client.aws_saml.client_id}"
  description = "Paste this URL into IAM Identity Center as the external IdP metadata URL."
}

output "auth0_saml_login_url" {
  value       = "https://${var.auth0_domain}/samlp/${auth0_client.aws_saml.client_id}"
  description = "IdP-initiated SSO URL (if needed)."
}
