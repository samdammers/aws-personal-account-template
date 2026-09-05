###############################################################################
# Default VPC — adopted (not created) into Terraform management
#
# Every AWS account gets one of these per region for free. There's no
# `terraform import` needed for this specific resource type: the provider
# detects the default VPC already exists and adopts it into state instead of
# trying to create a second one (which AWS wouldn't allow anyway). It's
# declared here mainly so the default security group below — which every
# default VPC ships with, and which is otherwise unmanaged and permissive —
# is something this stack can actually lock down.
#
# The values below match what AWS actually sets on a freshly-created default
# VPC (DNS support/hostnames both on) — if you're adopting a default VPC
# someone has since changed, check those match before applying, or Terraform
# will change them back.
###############################################################################

resource "aws_default_vpc" "default" {
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "default"
  }
}

output "default_vpc_id" {
  value       = aws_default_vpc.default.id
  description = "The account's default VPC, now Terraform-managed. Other stacks (foundryvtt-aws, valheim, etc.) look this up independently via `data \"aws_vpc\" \"default\" { default = true }` and don't need to reference this output."
}

###############################################################################
# Default security group — locked down to zero rules
#
# AWS's default VPC ships this security group with permissive rules (allow
# all traffic between members of the group, allow all outbound), and any ENI
# that isn't explicitly given a security group falls back to it. CIS AWS
# Foundations 5.3 flags this for exactly that reason — it's an easy way for a
# misconfigured resource to end up more open than intended, silently, since
# nobody's watching this particular group.
#
# Declaring aws_default_security_group with no ingress/egress blocks is how
# the AWS provider expects you to express "this group should have no rules at
# all" — it adopts the existing default SG and removes whatever rules it had.
# Safe here since nothing in this account currently uses the default SG
# (every real resource already has its own purpose-built one) — if that's not
# true for you, add your own rules back before applying, or drop this
# resource and leave the default SG alone.
###############################################################################

resource "aws_default_security_group" "default" {
  vpc_id = aws_default_vpc.default.id
}
