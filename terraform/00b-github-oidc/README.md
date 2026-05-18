# 00b — GitHub OIDC Integration

> Sets up OpenID Connect authentication between GitHub Actions and AWS, eliminating long-lived access keys.

## What This Module Creates

| Resource | Purpose |
|----------|---------|
| OIDC Identity Provider | Tells AWS to trust JWT tokens from GitHub Actions |
| IAM role `github-actions-plan` | Read-only role for `terraform plan` on PRs |
| IAM role `github-actions-apply` | Admin role for `terraform apply` on `main` branch |
| Trust policies | Restrict role assumption to this specific repo, with conditions |

## Why OIDC Instead of Access Keys?

| Static AWS Keys | OIDC |
|----------------|------|
| Long-lived (often years) | Temporary tokens (1 hour) |
| Need rotation | No rotation needed |
| Stored in GitHub Secrets | No secret stored |
| If leaked: catastrophic | If leaked: useless in 1h |
| Same key works from anywhere | Bound to specific repo/branch |

OIDC is the industry standard since 2022 and required by serious security audits.

## Deployment

### Prerequisites

The `00-bootstrap` module must be applied first. You need its outputs to fill `terraform.tfvars`.

### Step 1 — Configure backend and variables

Edit `versions.tf` and replace `BUCKET_NAME` with the value of bootstrap's `tfstate_bucket_name` output:

```bash
cd terraform/00-bootstrap
terraform output tfstate_bucket_name
```

Then copy the example tfvars file and fill it:

```bash
cd ../00b-github-oidc
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your actual values
```

### Step 2 — Apply

```bash
terraform init
terraform plan
terraform apply
```

### Step 3 — Capture the role ARNs

```bash
terraform output github_actions_plan_role_arn
terraform output github_actions_apply_role_arn
```

These ARNs will be used in your GitHub Actions workflows.

## Security Model

### Trust Policy for the Plan role

The plan role can be assumed by **any workflow** running in your repo (on PRs from contributors, on pushes to feature branches, etc.). It has **read-only** AWS permissions plus narrow state access.

Subject claim pattern:
```
repo:OWNER/REPO:*
```

### Trust Policy for the Apply role

The apply role is much more restricted. It can ONLY be assumed when:

1. The workflow runs on the `main` branch of your repo, OR
2. The workflow runs within a GitHub Environment named `production` (which can require manual approval)

Subject claim pattern:
```
repo:OWNER/REPO:ref:refs/heads/main
repo:OWNER/REPO:environment:production
```

This means: even if an attacker pushes malicious Terraform code on a feature branch, they CANNOT apply it. Only merged + approved code runs apply.

## Cost

This module creates IAM resources only, which are **free**. No monthly cost.

## Verifying the Setup

After apply, you can verify the OIDC provider in AWS:

```bash
aws iam list-open-id-connect-providers
```

You should see the GitHub provider listed.

To verify the roles:

```bash
aws iam get-role --role-name media-landing-zone-github-actions-plan
aws iam get-role --role-name media-landing-zone-github-actions-apply
```

## Next Steps

Once these roles exist, you can write GitHub Actions workflows that authenticate to AWS without any secrets:

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCOUNT_ID:role/media-landing-zone-github-actions-plan
    aws-region: eu-west-3
```

See `.github/workflows/` at the repo root for the actual pipeline definitions.
