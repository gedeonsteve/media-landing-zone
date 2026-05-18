# ------------------------------------------------------------------------------
# Input variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "Short name used to prefix resources. Must match the bootstrap module."
  type        = string
  default     = "media-landing-zone"
}

variable "aws_region" {
  description = "AWS region for the OIDC resources (IAM is global, this is for the provider)."
  type        = string
  default     = "eu-west-3"
}

variable "github_owner" {
  description = "GitHub username or organization that owns the repository."
  type        = string
  # No default — must be provided explicitly to avoid trusting the wrong repo.
}

variable "github_repo" {
  description = "Name of the GitHub repository allowed to assume the IAM roles."
  type        = string
  default     = "media-landing-zone"
}

# These come from the bootstrap module outputs. Pass them as variables.
variable "tfstate_bucket_arn" {
  description = "ARN of the S3 bucket holding Terraform state (from bootstrap)."
  type        = string
}

variable "tfstate_lock_table_arn" {
  description = "ARN of the DynamoDB lock table (from bootstrap)."
  type        = string
}

variable "tfstate_kms_key_arn" {
  description = "ARN of the KMS key encrypting the state (from bootstrap)."
  type        = string
}
