# 00 — Bootstrap

> Creates the foundational AWS resources used as a remote backend for **all** other Terraform modules in this project.

## Resources Created

| Resource | Purpose |
|----------|---------|
| S3 bucket | Stores Terraform state files (versioned, KMS-encrypted, public access blocked) |
| DynamoDB table | Provides state locking to prevent concurrent applies |
| KMS key + alias | Encrypts the S3 bucket and DynamoDB table |

## The Chicken-and-Egg Problem

This module faces a paradox: it creates the resources that store Terraform state, yet it is itself a Terraform module that needs to store state somewhere.

The solution:

1. **First apply** runs with a **local state** (`terraform.tfstate` file on disk)
2. The S3 bucket and DynamoDB table get created
3. We then **migrate the local state to the S3 bucket** we just created
4. After migration, this module behaves like any other (remote state)

## Deployment

### Step 1 — First apply with local state

```bash
cd terraform/00-bootstrap
terraform init
terraform plan
terraform apply
```

You should see ~10 resources created. After apply, note the outputs (especially `tfstate_bucket_name`).

### Step 2 — Migrate local state to S3

Edit `versions.tf`:

1. Uncomment the `backend "s3"` block
2. Replace `BUCKET_NAME` with the actual bucket name from the `tfstate_bucket_name` output (e.g., `media-landing-zone-tfstate-123456789012`)

Then run:

```bash
terraform init -migrate-state
```

Terraform will detect the configuration change and prompt:

```
Do you want to copy existing state to the new backend?
```

Answer `yes`. Your local `terraform.tfstate` is now uploaded to S3.

### Step 3 — Clean up local state

After successful migration, delete the local state files:

```bash
rm -f terraform.tfstate terraform.tfstate.backup
```

These files are also in `.gitignore`, so they would never be committed anyway.

## Verification

Check that your state is now in S3:

```bash
aws s3 ls s3://media-landing-zone-tfstate-<account-id>/00-bootstrap/
```

You should see `terraform.tfstate`.

Check that the lock table works (any subsequent `terraform plan` will briefly acquire and release a lock):

```bash
aws dynamodb scan --table-name media-landing-zone-tfstate-lock
```

## Cost

| Resource | Monthly cost |
|----------|--------------|
| S3 bucket (storage of ~5 small state files) | < $0.01 |
| DynamoDB table (pay-per-request, very low usage) | < $0.10 |
| KMS key | $1.00 (flat) |
| **Total** | **~$1.10/month** |

## Why This Design

- **Versioning enabled**: recover from corrupted or accidentally-deleted state
- **KMS encryption**: state files often contain sensitive data (RDS passwords, API keys) — never store them in plaintext
- **DynamoDB locking**: prevents two engineers from running `terraform apply` simultaneously and corrupting state
- **`prevent_destroy` lifecycle**: prevents `terraform destroy` from accidentally deleting the backend that holds 100+ other states
- **Public access blocked**: triple-protection against accidentally exposing state to the internet
