# --- Optional: Route53 public hosted zone for a domain you already own ---
# Skipped (count = 0) unless domain_name is set. Deliberately doesn't
# register a new domain (aws_route53domains_registered_domain) - that's a
# real financial transaction with ongoing renewal costs and requires real
# contact/PII fields, which shouldn't be a one-click Terraform resource. This
# only creates the zone; if the domain is registered elsewhere, you still
# need to manually update your registrar's nameserver (NS) records to match
# the name_servers output below - Terraform can't do that part for you
# either, since it's on the registrar's side, not AWS's.
resource "aws_route53_zone" "main" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.domain_name
}

output "hosted_zone_id" {
  description = "Point downstream stacks' hosted_zone_id variable (e.g. valheim-aws-template) at this."
  value       = var.domain_name != "" ? aws_route53_zone.main[0].zone_id : null
}

output "hosted_zone_name_servers" {
  description = "If your domain is registered elsewhere, update your registrar's NS records to exactly these four."
  value       = var.domain_name != "" ? aws_route53_zone.main[0].name_servers : null
}
