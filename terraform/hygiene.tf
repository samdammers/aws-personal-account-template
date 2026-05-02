###############################################################################
# Account security contact — AWS uses this to notify you of security findings
###############################################################################

resource "aws_account_alternate_contact" "security" {
  alternate_contact_type = "SECURITY"
  name                   = var.my_gmail_address
  email_address          = var.my_gmail_address
  phone_number           = var.account_owner_phone
  title                  = "Account Owner"
}

###############################################################################
# Cost Anomaly Detection — free monitor; alerts on unexpected spend patterns
###############################################################################

resource "aws_ce_anomaly_monitor" "main" {
  name              = "personal-cost-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "main" {
  name      = "personal-anomaly-alerts"
  frequency = "DAILY"

  monitor_arn_list = [aws_ce_anomaly_monitor.main.arn]

  subscriber {
    type    = "EMAIL"
    address = var.my_gmail_address
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      values        = ["10"]
      match_options = ["GREATER_THAN_OR_EQUAL"]
    }
  }
}

###############################################################################
# IAM Access Analyzer — account-level (free; finds overly permissive resources)
###############################################################################

resource "aws_accessanalyzer_analyzer" "account" {
  analyzer_name = "personal-account-analyzer"
  type          = "ACCOUNT"
}

###############################################################################
# S3 Lifecycle — expire noncurrent versions after 30 days
# Versioning is already enabled on this bucket (aws_s3_bucket_versioning.images)
###############################################################################

resource "aws_s3_bucket_lifecycle_configuration" "images" {
  bucket = aws_s3_bucket.images.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}
