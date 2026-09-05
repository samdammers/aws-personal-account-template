# Personal AWS Account Bootstrap

Terraform to set up a personal AWS account the way you'd want a fresh one
configured: sign in via Google, or plain email/password if you don't have a
Google account (through Auth0 as a SAML identity provider fronting IAM
Identity Center) instead of an IAM user password, plus a handful of
free/cheap security baselines — CloudTrail, an org-wide Service Control
Policy, cost anomaly alerts, IAM Access Analyzer, a security contact.

This is a template: every account-specific value (AWS account ID, owner
email, Auth0 tenant, region, …) is a variable you supply via `.envrc`, not a
default baked into the repo.

**Single-user limitation:** this only supports one allowed identity —
`owner_email` is a single string, used directly as the account's security
contact, the Identity Center user looked up for the `PersonalAdmin`
assignment, and the `ALLOWED_EMAIL` both login guards check against. Adding a
second person (a spouse, a co-admin) isn't a config change here — it'd need a
list variable, a loop over Identity Center assignments, and an array check in
both Actions.

## What this sets up

- **AWS Organizations**, with IAM Identity Center (SSO) enabled
- **Google login for the AWS console**, via Auth0 acting as a SAML IdP in
  front of IAM Identity Center — no IAM user, no password to manage
- **Optionally, plain email/password sign-in instead** (`enable_database_connection`),
  for when there's no Google account to use at all — see
  [No Google account?](#no-google-account) below
- **Two login guards restricting that SSO app to you specifically** — the
  Google connection itself will still let *any* Google account complete the
  OAuth handshake (that's inherent to how social connections work — there's
  no separate "sign up form" to gate the way there is for username/password
  connections). A post-login Action denies the login outright unless the
  email matches `owner_email`, before any SAML assertion is issued, so a
  stranger can't actually get into your AWS account; a second,
  pre-registration Action tries to stop that far — refusing to even create a
  stranger's Auth0 user record in the first place — using the same email
  check, so it's safe to deploy from the start rather than needing a
  "sign in once first, then lock down" dance. (The database connection above
  doesn't need either guard for the same effect — its own `disable_signup`
  is reliably enforced, so there's no public sign-up surface to guard in the
  first place.) See [Important caveats](#important-caveats) for what each
  layer actually covers and where the uncertainty is.
- **A Service Control Policy** that (a) protects CloudTrail from being
  disabled/tampered with and (b) — more aggressively — denies almost all AWS
  API activity outside a single region you choose, org-wide. See the warning
  in `terraform/scp.tf` before applying: this is a deliberate one-region,
  one-person choice, not something to accept blindly.
- **CloudTrail** (management events, one S3-delivered copy is free), 365-day
  log retention
- **Cost Anomaly Detection**, **IAM Access Analyzer**, and an AWS account
  **security contact** — all free
- **The account's default VPC, adopted, with its default security group
  locked down to zero rules** — the SG every ENI without an explicit one
  falls back to, which AWS ships with permissive allow-all rules by default
  (CIS AWS Foundations 5.3). See [Important caveats](#important-caveats)
  before applying if you actually have something relying on the default SG.
- Optionally, your own **GCP OAuth 2.0 client** for the Google login instead
  of Auth0's shared dev keys (recommended once you're past just trying this
  out — see [GCP OAuth client](#gcp-oauth-client-optional) below)

## Prerequisites

- **An AWS account** — [sign up here](https://portal.aws.amazon.com/billing/signup)
  if you don't have one yet. Right after signup, while you're still on the
  root user: set a strong, unique root password, **enable MFA on it**, and
  save both in a password manager — root has no permissions boundary at all,
  and this is the one credential nothing in this repo can help you recover if
  you lose it. Then use root just long enough to run the bootstrap sequence
  below; once Apply 3 assigns your authenticated identity (Google or the
  optional database connection) the `PersonalAdmin` permission set, switch to
  signing in through IAM Identity Center (the SSO login this repo sets up)
  for everyday use, and set root
  aside as a break-glass credential you're not routinely typing in anywhere.
- **IAM Identity Center enabled once, manually, in the console** — Terraform
  can't turn this on itself (AWS requires the first activation to happen in
  the console): AWS Console → search "IAM Identity Center" → **Enable**.
  Everything after that first click is managed by this Terraform.
- **An Auth0 account** — [auth0.com](https://auth0.com) has a free tier that's
  plenty for one person. Create a **Machine-to-Machine application** with
  access to the **Auth0 Management API** (Applications → Create Application →
  Machine to Machine, then authorize it for the "Auth0 Management API" with
  whatever scopes it prompts for) — its Domain/Client ID/Client Secret are
  `auth0_domain` / `auth0_management_client_id` / `auth0_management_client_secret`.
- **Terraform >= 1.6**, and AWS CLI credentials with enough permissions to
  create an AWS Organization, IAM Identity Center resources, SCPs, CloudTrail,
  and S3/CloudFront — for a personal account's own root/admin credentials this
  is generally not an issue.

## Configure

```bash
cp .envrc.example .envrc   # fill in your values, then: direnv allow
cd terraform/
terraform init
```

`.envrc` and `terraform.tfvars` are both gitignored — see `.envrc.example` for
the full list of variables (`terraform/variables.tf` is the source of truth).
This repo uses `TF_VAR_*` environment variables (via [direnv](https://direnv.net/))
rather than a tracked `terraform.tfvars`, so nothing here depends on you
remembering to `-var-file` anything.

## Bootstrap sequence

This can't all happen in a single `terraform apply` — IAM Identity Center's
SAML metadata only exists *after* it's enabled, and Auth0's SAML app needs
that metadata to configure itself, and IAM Identity Center needs Auth0's
metadata right back. Three applies, in order, with one manual step in the
middle that neither provider has a resource for:

**Apply 1 — AWS Org + SSO baseline:**
```bash
terraform apply -target=aws_organizations_organization.main
terraform apply -target=aws_ssoadmin_permission_set.admin -target=aws_ssoadmin_managed_policy_attachment.admin
```
Then, in the AWS Console: **IAM Identity Center → Settings**, copy the **ACS
URL** and **Issuer URL** from the SAML metadata section into your `.envrc` as
`TF_VAR_sso_saml_acs_url` / `TF_VAR_sso_saml_audience`, and `direnv allow`
again. While you're on that Settings page, also check **Automatic
provisioning** is **off** — if it's on, any Google account that completes the
SAML flow gets auto-created as an Identity Center user. Apply 3 below assigns
access explicitly instead; the Auth0 Action guard (Apply 2) is a second,
Terraform-managed layer on top of whichever way you leave this console
setting, not a replacement for checking it.

**Apply 2 — Auth0 SAML app + Google connection + both login guards:**
```bash
terraform apply -target=auth0_client.aws_saml -target=auth0_connection.google -target=auth0_connection_clients.google_on_aws -target=auth0_trigger_action.restrict_to_owner -target=auth0_trigger_action.restrict_to_owner_pre_registration
```
(the two `auth0_trigger_action` resources pull in their respective
`auth0_action` resources automatically — including them here means both
guards are live as soon as the SAML app exists, rather than only from Apply 3
onward; being keyed to an email match rather than "does a user already
exist," neither one risks blocking your own first login below.) Note the
`auth0_saml_metadata_url` output.

**Manual step (one-time, provider gap — neither the AWS nor Auth0 Terraform
provider exposes this):**
AWS Console → **IAM Identity Center → Settings → Change identity source →
External IdP**, paste in the `auth0_saml_metadata_url` value. Or via CLI:
```bash
aws sso-admin put-identity-provider-configuration \
  --instance-arn "$(terraform output -raw sso_instance_arn)" \
  --identity-provider-url "$(terraform output -raw auth0_saml_metadata_url)" \
  --region "$TF_VAR_aws_region"
```

**Apply 3 — user assignment (after your first Google login):**
Sign in once through the new SSO login flow so IAM Identity Center's identity
store has a record of your user, then uncomment the `data`/`resource` blocks
in `aws_sso.tf` and:
```bash
terraform apply
```

After this, `terraform apply` behaves like any normal stack — the sequencing
above is only needed for the initial bootstrap.

## GCP OAuth client (optional)

Auth0's shared "dev keys" for Google login work fine to start, but they show a
generic Auth0 consent screen and Google may throttle/warn on them long-term.
For your own branded OAuth client:

1. [Google Cloud Console](https://console.cloud.google.com/) → create or
   select a project.
2. **APIs & Services → OAuth consent screen** — External, add your Gmail as a
   test user.
3. **APIs & Services → Credentials → Create OAuth Client ID** — Web
   application, with an authorized redirect URI of
   `https://<your-auth0-domain>/login/callback`.
4. Put the client ID/secret in `.envrc` as `TF_VAR_google_oauth_client_id` /
   `TF_VAR_google_oauth_client_secret`.

There's no Terraform resource for the OAuth client itself (`terraform/gcp.tf`
documents this gap and has commented-out blocks for the two related API
enablements, if you want to manage those two via the `google` provider).

## No Google account?

Set `enable_database_connection = true` (or `TF_VAR_enable_database_connection=true`
in `.envrc`) to get a plain email/password sign-in option alongside Google —
no Google account needed at all. These resources don't depend on anything
from the [bootstrap sequence](#bootstrap-sequence)'s manual steps, so they
can be applied any time — added to Apply 2's command
(`-target=auth0_connection_clients.database_on_aws -target=auth0_user.owner`)
or as their own separate `terraform apply` afterward. This creates:

- An Auth0 database connection, with self-service sign-up genuinely disabled
  (`disable_signup`, reliably enforced for this connection type — see
  [Important caveats](#important-caveats) for why that's *not* the same
  confidence level as for the Google connection)
- The one account you're actually meant to use, at `owner_email`, created
  directly by Terraform via `auth0_user` — never through a public sign-up
  form

**About the password:** Terraform generates a random throwaway one
(`random_password.owner_database`) purely to satisfy Auth0's "a user needs a
password" requirement at creation time. That is **not** meant to be your
actual password, and you shouldn't try to find out what it is — after
applying, go to the Auth0 dashboard → **User Management → Users** → your
`owner_email` user → **Reset Password**, and set your real password there
directly through Auth0. That real password then never touches Terraform,
`.envrc`, or the state file at all. (Putting a real, chosen password into a
Terraform variable would be a mistake regardless of `sensitive = true` —
that flag only redacts CLI/plan output, it does nothing to the state file
itself, which stores every managed resource's actual values in plain JSON.)

Both connections can be enabled at once — Auth0's login page for the SAML
app will offer either, and either one satisfies the same `owner_email` check
in both guards.

## Important caveats

- **The region-lock SCP in `scp.tf` is aggressive by design** — it denies
  nearly all AWS API activity anywhere outside `var.aws_region` for the whole
  organization (a curated allowlist of IAM/Route53/S3/CloudFront/ACM/billing
  and similar global/free services is exempted, since those aren't
  region-scoped the same way). If you plan to use other regions, either widen
  the `NotAction` allowlist in `scp.tf` or remove that statement (and its
  `aws_organizations_policy_attachment`) entirely before applying.
- **IAM Identity Center's first activation must happen manually in the
  console** — there's no Terraform resource for it, only a data source that
  reads it back once it exists.
- **The Auth0 ⇄ IAM Identity Center SAML wiring is genuinely circular** — each
  side needs the other's metadata to configure itself, which is why this is a
  three-apply bootstrap with one manual step, not a single `terraform apply`.
- Auth0's Management API M2M application needs to be created **once, by
  hand**, before `terraform init` — the `auth0` provider authenticates with
  its credentials, so there's no way to have Terraform create the very
  credentials it needs to run.
- **The pre-registration guard (`auth0_action.restrict_to_owner_pre_registration`)
  is unconfirmed, not the authoritative guard** — Auth0's "pre user
  registration" flow is primarily documented around database/passwordless
  signups; whether it actually fires for a social (Google) connection at all
  hasn't been confirmed here, only that `terraform apply` accepts the
  resource. If it turns out not to fire for this connection type, it's a
  harmless no-op — the post-login guard below is what actually keeps a
  stranger out of AWS regardless of whether this one does anything. Also
  unconfirmed: whether `event.client` is populated the same way as in
  post-login, so its "just the AWS SAML app" scoping may be less precise.
- **The post-login guard (`auth0_action.restrict_to_owner`) only covers the
  AWS SAML app** — it checks `event.client.client_id` and returns early for
  any other Auth0 application, so it won't interfere if you add more apps to
  this same Auth0 tenant later. It also only fires on a login attempt; it
  doesn't restrict who's *allowed to be invited/assigned* inside IAM Identity
  Center itself (that's what turning off automatic provisioning, above, is
  for) — the
  two are deliberately layered, not redundant. The comparison is
  case-insensitive on purpose (Google's `email` claim is lowercase in
  practice, but there's no reason a casing edge case should be what locks the
  account owner out). None of this touches the AWS **root** login at all —
  root sign-in doesn't go through Auth0 or this SAML app, so it's unaffected
  by this guard (or by IAM Identity Center being misconfigured, or by Auth0
  being down) and remains your break-glass path — see the root guidance in
  [Prerequisites](#prerequisites).
- **The optional database connection (`enable_database_connection`) doesn't
  rely on either guard for its safety** — its `disable_signup` is reliably
  enforced (this is the connection type Auth0 actually documents that option
  for), so there's no public sign-up flow for a stranger to attempt in the
  first place; the only user that can ever exist on it is the one
  `auth0_user` Terraform creates directly via the Management API. If the
  pre-registration Action does fire for this connection type (more plausible
  here than for Google, since this is the documented use case for that
  trigger), it still wouldn't see a Management-API-created user go through
  it — that's a separate path from the public registration flow the trigger
  guards.
- **`aws_default_vpc`/`aws_default_security_group` adopt pre-existing AWS
  resources rather than creating new ones** — there's no `terraform import`
  step needed, but it does mean `terraform plan` will show them as "will be
  created" the first time even though nothing is actually being created (the
  provider adopts the account's real default VPC/SG into state instead). The
  default SG gets locked to zero rules on apply — safe as long as nothing in
  your account actually relies on it (check with
  `aws ec2 describe-network-interfaces --filters Name=group-id,Values=<default-sg-id>`
  first if you're not sure).
