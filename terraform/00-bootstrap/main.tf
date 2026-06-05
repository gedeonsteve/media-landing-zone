/**
 * # Bootstrap — Terraform State Backend
 *
 * This module creates the foundational AWS resources needed to store
 * Terraform state remotely:
 *
 *   - S3 bucket for state storage (versioned + encrypted)
 *   - DynamoDB table for state locking
 *   - KMS key for state encryption
 *
 * It is the ONLY module that uses a local state backend.
 * After the initial apply, the state is migrated to the S3 bucket
 * created here, and all subsequent modules use S3 + DynamoDB.
 *
 * ## Usage
 *
 * Initial apply (local state):
 *   terraform init
 *   terraform apply
 *
 * Then uncomment the `backend "s3"` block in versions.tf and migrate:
 *   terraform init -migrate-state
 *
 * After that, this state is also stored remotely like everything else.
 */

# ------------------------------------------------------------------------------
# Data sources — current AWS identity
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ------------------------------------------------------------------------------
# Local values — naming conventions
# ------------------------------------------------------------------------------

locals {
  # Bucket and table names must be globally unique for S3, account-unique for DynamoDB.
  # We use the account ID to ensure uniqueness without revealing the project name.
  account_id   = data.aws_caller_identity.current.account_id
  region       = data.aws_region.current.name
  bucket_name  = "${var.project_name}-tfstate-${local.account_id}"
  lock_table   = "${var.project_name}-tfstate-lock"
  kms_alias    = "alias/${var.project_name}-tfstate"

  common_tags = {
    Project     = var.project_name
    ManagedBy   = "Terraform"
    Component   = "Bootstrap"
    Environment = "shared"
    Owner       = "gedeonsteve"
    Repository  = "media-landing-zone"
  }
}

# ------------------------------------------------------------------------------
# KMS Key — encrypts the state at rest
# ------------------------------------------------------------------------------

resource "aws_kms_key" "tfstate" {
  description             = "KMS key for Terraform state encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-tfstate-key"
  })
}

resource "aws_kms_alias" "tfstate" {
  name          = local.kms_alias
  target_key_id = aws_kms_key.tfstate.key_id
}

# ------------------------------------------------------------------------------
# S3 Bucket — stores the Terraform state files
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "tfstate" {
  bucket = local.bucket_name

  # SAFETY: prevent accidental destruction of the state bucket.
  # Even `terraform destroy` will fail on this resource.
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = local.bucket_name
  })
}

# Block ALL public access — state files must NEVER be public.
resource "aws_s3_bucket_public_access_block" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning — recover from corrupted/deleted state files.
resource "aws_s3_bucket_versioning" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encrypt the state files at rest with our KMS key.
resource "aws_s3_bucket_server_side_encryption_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tfstate.arn
    }
    bucket_key_enabled = true
  }
}

# Lifecycle rule — clean up old non-current versions after 90 days.
# Saves storage cost without losing recent recoverability.
resource "aws_s3_bucket_lifecycle_configuration" "tfstate" {
  bucket = aws_s3_bucket.tfstate.id

  rule {
    id     = "cleanup-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ------------------------------------------------------------------------------
# DynamoDB Table — provides state locking to prevent concurrent applies
# ------------------------------------------------------------------------------

resource "aws_dynamodb_table" "tfstate_lock" {
  name         = local.lock_table
  billing_mode = "PAY_PER_REQUEST" # Cheaper than provisioned for low-traffic locks
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  # Encrypt the table at rest with our KMS key.
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.tfstate.arn
  }

  # SAFETY: prevent accidental destruction.
  lifecycle {
    prevent_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = local.lock_table
  })
}
