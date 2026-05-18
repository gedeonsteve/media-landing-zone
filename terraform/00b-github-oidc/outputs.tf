# ------------------------------------------------------------------------------
# Outputs — used to configure the GitHub Actions workflows
# ------------------------------------------------------------------------------

output "github_oidc_provider_arn" {
  description = "ARN of the GitHub OIDC Identity Provider in AWS."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_plan_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions on PRs (read-only)."
  value       = aws_iam_role.github_actions_plan.arn
}

output "github_actions_apply_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions on main (admin)."
  value       = aws_iam_role.github_actions_apply.arn
}
