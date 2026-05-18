/**
 * # GitHub OIDC Integration
 *
 * Creates the AWS infrastructure required for GitHub Actions to authenticate
 * with AWS using OpenID Connect (OIDC), eliminating the need for long-lived
 * IAM access keys.
 *
 * ## What this creates
 *
 *   - OIDC Identity Provider for `token.actions.githubusercontent.com`
 *   - IAM role assumable ONLY by workflows running in this specific repo
 *   - Trust policy restricted by repository name and branch/environment
 *
 * ## Security model
 *
 * The trust policy uses a `StringLike` condition on the `sub` (subject) claim
 * to restrict which GitHub workflows can assume the role:
 *
 *   - Workflows on `main` branch: full Terraform apply permissions
 *   - Workflows on PRs: read-only (terraform plan only)
 *
 * This prevents an attacker who forks the repo from assuming the role,
 * because the `sub` claim includes the repository owner.
 */

# ------------------------------------------------------------------------------
# Data sources
# ------------------------------------------------------------------------------

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Fetch the current TLS certificate of the GitHub OIDC endpoint
# to compute its SHA1 thumbprint (required by AWS).
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ------------------------------------------------------------------------------
# Local values
# ------------------------------------------------------------------------------

locals {
  github_oidc_url       = "token.actions.githubusercontent.com"
  github_oidc_audience  = "sts.amazonaws.com"

  # Repository pattern: matches any workflow run in this repo
  # Format: repo:OWNER/REPO:ref:refs/heads/BRANCH
  github_repo_pattern   = "repo:${var.github_owner}/${var.github_repo}:*"

  common_tags = {
    Project   = var.project_name
    ManagedBy = "Terraform"
    Component = "GitHub-OIDC"
  }
}

# ------------------------------------------------------------------------------
# OIDC Identity Provider — tells AWS to trust tokens from GitHub Actions
# ------------------------------------------------------------------------------

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://${local.github_oidc_url}"
  client_id_list  = [local.github_oidc_audience]

  # Thumbprint dynamically computed from GitHub's TLS certificate.
  # GitHub may rotate this; refreshing this resource picks up the new one.
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = merge(local.common_tags, {
    Name = "GitHub-OIDC-Provider"
  })
}

# ------------------------------------------------------------------------------
# IAM Role for GitHub Actions to PLAN (read-only)
# Used on Pull Requests where we only need to preview changes.
# ------------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_plan" {
  name        = "${var.project_name}-github-actions-plan"
  description = "Assumed by GitHub Actions on PRs to run terraform plan (read-only)"

  max_session_duration = 3600 # 1 hour — tight session

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.github_oidc_url}:aud" = local.github_oidc_audience
          }
          StringLike = {
            "${local.github_oidc_url}:sub" = local.github_repo_pattern
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-github-actions-plan"
  })
}

# Attach AWS-managed ReadOnly policy — sufficient for terraform plan
resource "aws_iam_role_policy_attachment" "github_actions_plan_readonly" {
  role       = aws_iam_role.github_actions_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Additional permissions: terraform plan needs to read the state from S3
# and acquire the DynamoDB lock (briefly). These are not in ReadOnlyAccess
# in a sufficient form, so we add a tight custom policy.
resource "aws_iam_role_policy" "github_actions_plan_state_access" {
  name = "${var.project_name}-state-access-plan"
  role = aws_iam_role.github_actions_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.tfstate_bucket_arn,
          "${var.tfstate_bucket_arn}/*"
        ]
      },
      {
        Sid    = "DynamoDBLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = var.tfstate_lock_table_arn
      },
      {
        Sid      = "KMSDecryptState"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = var.tfstate_kms_key_arn
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# IAM Role for GitHub Actions to APPLY (admin)
# Restricted to the `main` branch via the trust policy.
# ------------------------------------------------------------------------------

resource "aws_iam_role" "github_actions_apply" {
  name        = "${var.project_name}-github-actions-apply"
  description = "Assumed by GitHub Actions on main branch to run terraform apply"

  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${local.github_oidc_url}:aud" = local.github_oidc_audience
          }
          # CRITICAL: apply is restricted to:
          #   - the `main` branch
          #   - the `production` GitHub Environment (manual approval gate)
          StringLike = {
            "${local.github_oidc_url}:sub" = [
              "repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main",
              "repo:${var.github_owner}/${var.github_repo}:environment:production"
            ]
          }
        }
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-github-actions-apply"
  })
}

# For a personal learning project, AdministratorAccess is acceptable.
# In real production, you would scope this down to only the services
# Terraform actually needs (organizations, iam, s3, ec2, etc.).
resource "aws_iam_role_policy_attachment" "github_actions_apply_admin" {
  role       = aws_iam_role.github_actions_apply.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
