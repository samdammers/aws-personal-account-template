# Personal AWS Account Bootstrap

Terraform to set up a personal AWS account the way you'd want a fresh one
configured: sign in via Google (through Auth0 as a SAML identity provider
fronting IAM Identity Center) instead of an IAM user password, plus a handful
of free/cheap security baselines — CloudTrail, an org-wide Service Control
Policy, cost anomaly alerts, IAM Access Analyzer, a security contact.

This is a template: every account-specific value (AWS account ID, Gmail
address, Auth0 tenant, region, …) is a variable you supply via `.envrc`, not a
default baked into the repo.

## What this sets up

- **AWS Organizations**, with IAM Identity Center (SSO) enabled
- **Google login for the AWS console**, via Auth0 acting as a SAML IdP in
  front of IAM Identity Center — no IAM user, no password to manage
- **A Service Control Policy** that (a) protects CloudTrail from being
  disabled/tampered with and (b) — more aggressively — denies almost all AWS
  API activity outside a single region you choose, org-wide. See the warning
  in `terraform/scp.tf` before applying: this is a deliberate one-region,
  one-person choice, not something to accept blindly.
- **CloudTrail** (management events, one S3-delivered copy is free), 365-day
  log retention
- **Cost Anomaly Detection**, **IAM Access Analyzer**, and an AWS account
  **security contact** — all free
- Optionally, your own **GCP OAuth 2.0 client** for the Google login instead
  of Auth0's shared dev keys (recommended once you're past just trying this
  out — see [GCP OAuth client](#gcp-oauth-client-optional) below)

## Prerequisites

- **An AWS account** — [sign up here](https://portal.aws.amazon.com/billing/signup)
  if you don't have one yet.
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
again.

**Apply 2 — Auth0 SAML app + Google connection:**
```bash
terraform apply -target=auth0_client.aws_saml -target=auth0_connection.google -target=auth0_connection_clients.google_on_aws
```
Note the `auth0_saml_metadata_url` output.

**Manual step (one-time, provider gap — neither the AWS nor Auth0 Terraform
provider exposes this):**
AWS Console → **IAM Identity Center → Settings → Change identity source →
External IdP**, paste in the `auth0_saml_metadata_url` value. Or via CLI:
```bash
aws sso-admin put-identity-provider-configuration \
  --instance-arn "$(terraform output -raw sso_instance_arn)" \
  --identity-provider-url "$(terraform output -raw auth0_saml_metadata_url)" \
  --region <your-aws-region>
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
