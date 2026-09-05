terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    auth0 = {
      source  = "auth0/auth0"
      version = "~> 1.4"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      ManagedBy = "terraform"
      Repo      = var.repo_tag
    }
  }
}

provider "auth0" {
  domain        = var.auth0_domain
  client_id     = var.auth0_management_client_id
  client_secret = var.auth0_management_client_secret
}
