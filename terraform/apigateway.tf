# --- API Gateway CloudWatch logging role ---
# This is a singleton PER AWS ACCOUNT/REGION, not per-API - aws_api_gateway_account
# sets it account-wide, so any downstream stack (a game-server template, for
# instance) that enables access_log_settings on an API Gateway stage relies
# on this existing, but shouldn't declare its own copy - two stacks racing to
# manage the same account-wide setting would fight over (and risk clobbering
# on destroy) whichever one applied last. This used to live in whichever
# downstream stack happened to apply first (foundryvtt-aws, in this account's
# case) - moved here since it's genuinely account-level shared infrastructure,
# same role the artifacts bucket and the optional hosted zone already play.
resource "aws_iam_role" "apigw_cloudwatch" {
  # Keeping the pre-existing name rather than renaming to something generic:
  # an IAM role's name is ForceNew, so renaming would destroy and recreate
  # it (and briefly break access logging for every stack depending on it)
  # for no functional benefit - it's just a role name, not user-facing.
  name = "foundry-apigw-cloudwatch"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "apigw_cloudwatch" {
  role       = aws_iam_role.apigw_cloudwatch.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_api_gateway_account" "main" {
  cloudwatch_role_arn = aws_iam_role.apigw_cloudwatch.arn
}

output "apigateway_cloudwatch_role_arn" {
  description = "For reference only - downstream stacks with their own API Gateway stage don't need to set anything to use this, it's account-wide automatically."
  value       = aws_iam_role.apigw_cloudwatch.arn
}
