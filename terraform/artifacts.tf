###############################################################################
# General-purpose artifacts bucket — a home for Terraform state (other
# personal stacks point their own backend config at this) plus any other
# build/deploy artifacts.
###############################################################################

resource "aws_s3_bucket" "artifacts" {
  bucket = "artifacts-${var.aws_account_id}"
}

resource "aws_s3_bucket_versioning" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Versioning is what makes this safe as a state bucket (bad apply / accidental
# delete is recoverable), but left unbounded it grows forever — expire old
# noncurrent versions rather than keeping every one indefinitely.
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "expire-noncurrent-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
}

output "artifacts_bucket" {
  value       = aws_s3_bucket.artifacts.id
  description = "General-purpose bucket for Terraform state and other build/deploy artifacts. Point other stacks' backend config at this bucket."
}
