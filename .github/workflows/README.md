# GitHub Actions Workflows

This directory contains the CI/CD pipelines that automate Terraform operations against AWS.

## Workflows Overview

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `terraform-plan.yml` | Pull Request on `terraform/**` | Lints, validates, scans, and plans changes. Comments the plan on the PR. |
| `terraform-apply.yml` | Merge to `main` or manual | Applies validated changes. Requires manual approval via the `production` environment. |

## Authentication: OIDC, No Static Keys

Both workflows authenticate to AWS using OpenID Connect (OIDC). No long-lived AWS access keys are stored in GitHub Secrets.

The IAM roles are created by the `terraform/00b-github-oidc` module:

- **Plan role** (`media-landing-zone-github-actions-plan`): read-only, used on PRs.
- **Apply role** (`media-landing-zone-github-actions-apply`): admin, restricted to `main` branch and `production` environment.

## Required Repository Configuration

Before these workflows can run, the following must be set up in repository settings:

### Variables (Settings → Secrets and variables → Actions → Variables tab)

Define these as **repository variables** (not secrets — they are ARNs, not sensitive):

| Name | Value |
|------|-------|
| `AWS_PLAN_ROLE_ARN` | Output `github_actions_plan_role_arn` from `00b-github-oidc` |
| `AWS_APPLY_ROLE_ARN` | Output `github_actions_apply_role_arn` from `00b-github-oidc` |

### Environments (Settings → Environments)

Create an environment named `production` with these settings:

- ✅ Required reviewers: yourself (and any other approver)
- ✅ Restrict to selected branches: `main`
- ⏱️ Wait timer: 0 minutes (or higher if you want a cooldown)

### Branch protection (Settings → Branches)

Protect the `main` branch:

- ✅ Require a pull request before merging
- ✅ Require status checks to pass before merging
  - Required checks: `Terraform Plan / Plan terraform/00-bootstrap` (add others as you create modules)
- ✅ Require linear history (recommended)

## How the Plan Workflow Works

1. Developer opens a PR that modifies files under `terraform/`
2. The workflow detects which top-level modules changed (e.g., `terraform/00-bootstrap`)
3. For each changed module, in parallel:
   - Check format (`terraform fmt`)
   - Initialize backend (`terraform init`)
   - Validate syntax (`terraform validate`)
   - Lint (`tflint`)
   - Security scan (`tfsec`)
   - Generate plan (`terraform plan`)
4. The plan output is posted as a comment on the PR
5. If any step fails, the PR check fails and the PR cannot be merged

## How the Apply Workflow Works

1. PR is merged to `main` (or workflow is triggered manually)
2. The workflow detects which modules changed in the merged commit
3. Job is queued, **waiting for manual approval** because it targets the `production` environment
4. Approver receives a notification and clicks "Approve and deploy" in GitHub
5. For each module, sequentially (not parallel — safer):
   - Initialize backend
   - Run `terraform apply -auto-approve`
6. The Terraform outputs are saved as a GitHub artifact for 30 days

## Security Considerations

### Why split into plan and apply roles?

The `plan` role can be assumed by **any PR**, including from forks (potentially malicious contributors). Having it limited to read-only AWS access means a bad actor cannot exfiltrate data or create resources.

The `apply` role has admin permissions but its trust policy restricts it to:
- `ref:refs/heads/main` (the `main` branch ref)
- `environment:production` (the production environment, gated by manual approval)

This makes it impossible to apply Terraform from a feature branch or a fork.

### Plan output truncation

The plan output is truncated to ~60,000 characters when posted to the PR. Full output is always available in the workflow logs. This prevents leaking sensitive values (e.g., resource ARNs, account IDs) in PR comments while keeping reviews actionable.

## Local Development

You can still run Terraform locally with your AWS CLI credentials, but the recommended workflow is:

1. Make changes locally
2. Run `terraform fmt && terraform validate` locally
3. Push to a feature branch, open a PR
4. Let the pipeline run the plan
5. Review the plan in the PR comment
6. Merge → review the apply approval in the GitHub Environments page
7. Approve → wait for apply to complete

This workflow ensures that every change is reviewable, auditable, and undoable.

## Next Steps

After this is working, consider adding:

- `terraform-drift-detection.yml` — daily cron that detects unmanaged changes
- `security-scan.yml` — extended security scanning (Checkov, Snyk IaC)
- `cost-estimation.yml` — Infracost diff on PRs
- `docs-generation.yml` — auto-generate `README.md` per module with `terraform-docs`