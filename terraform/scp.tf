###############################################################################
# SCP — security guardrails applied to the org root
###############################################################################

resource "aws_organizations_policy" "guardrails" {
  name        = "guardrails"
  description = "Protect CloudTrail from tampering; deny all activity outside ap-southeast-4."
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
        Sid    = "DenyOutsideMelbourne"
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
            "aws:RequestedRegion" = "ap-southeast-4"
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
