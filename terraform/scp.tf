###############################################################################
# SCP — security guardrails applied to the org root
#
# WARNING: the second statement below denies almost all AWS API activity
# anywhere outside var.aws_region, for the entire organization. That's a
# deliberate personal-account choice (one region, one person, no surprise
# spend/resources appearing somewhere you're not watching) — not something to
# apply without thinking about it. If you use (or plan to use) other regions —
# CloudFront's edge locations aside, which are already exempted below along
# with IAM/Route53/S3/billing/support — either add those services to the
# NotAction allowlist or remove this statement (and its attachment) entirely.
###############################################################################

resource "aws_organizations_policy" "guardrails" {
  name        = "guardrails"
  description = "Protect CloudTrail from tampering; deny all activity outside var.aws_region."
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ProtectCloudTrail"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:UpdateTrail",
          "cloudtrail:PutEventSelectors",
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyOutsideAllowedRegion"
        Effect = "Deny"
        NotAction = [
          "account:*",
          "acm:*",
          "aws-portal:*",
          "budgets:*",
          "ce:*",
          "cloudfront:*",
          "cur:*",
          "fms:*",
          "globalaccelerator:*",
          "health:*",
          "iam:*",
          "identitystore:*",
          "importexport:*",
          "networkmanager:*",
          "organizations:*",
          "pricing:*",
          "route53:*",
          "route53domains:*",
          "s3:*",
          "shield:*",
          "sso:*",
          "sso-admin:*",
          "sts:*",
          "support:*",
          "tag:*",
          "trustedadvisor:*",
          "waf:*",
          "wafv2:*"
        ]
        Resource = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = var.aws_region
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "guardrails" {
  policy_id = aws_organizations_policy.guardrails.id
  target_id = aws_organizations_organization.main.roots[0].id
}
