# ------------------------------------------------------------------------------
# Provider and Terraform version constraints
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.70"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  # ----------------------------------------------------------------------------
  # Backend configuration — uses the S3 bucket created in 00-bootstrap.
  # REPLACE BUCKET_NAME with the actual value from bootstrap's
  # `tfstate_bucket_name` output before running terraform init.
  # ----------------------------------------------------------------------------

  backend "s3" {
    bucket         = "media-landing-zone-tfstate-021502749428" # ⚠️ REPLACE ME
    key            = "00b-github-oidc/terraform.tfstate"
    region         = "eu-west-3"
    dynamodb_table = "media-landing-zone-tfstate-lock"
    encrypt        = true
    kms_key_id     = "alias/media-landing-zone-tfstate"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
    }
  }
}
