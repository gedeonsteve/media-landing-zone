# ------------------------------------------------------------------------------
# Provider and Terraform version constraints
# ------------------------------------------------------------------------------

terraform {
  required_version = ">= 1.6"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.50"
    }
  }

  # ----------------------------------------------------------------------------
  # Backend configuration — INITIALLY COMMENTED OUT
  #
  # On first apply, this module uses LOCAL state (terraform.tfstate file).
  # After the first apply succeeds, the S3 bucket and DynamoDB table will
  # exist, and you can migrate the state by:
  #
  #   1. Uncomment the backend block below
  #   2. Replace BUCKET_NAME with the value of the `tfstate_bucket_name` output
  #   3. Run: terraform init -migrate-state
  #
  # Once migrated, this module's state lives in S3 like all the others.
  # ----------------------------------------------------------------------------

  backend "s3" {
    bucket         = "media-landing-zone-tfstate-821650122484"                  # from tfstate_bucket_name output
    key            = "00-bootstrap/terraform.tfstate"
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
