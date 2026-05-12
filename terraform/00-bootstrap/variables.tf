# ------------------------------------------------------------------------------
# Input variables
# ------------------------------------------------------------------------------

variable "project_name" {
  description = "Short name used to prefix resources. Lowercase, no spaces."
  type        = string
  default     = "media-landing-zone"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, digits, and hyphens."
  }
}

variable "aws_region" {
  description = "AWS region for the Terraform state backend resources."
  type        = string
  default     = "eu-west-3"
}
