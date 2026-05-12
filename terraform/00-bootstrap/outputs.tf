# ------------------------------------------------------------------------------
# Outputs — used by other Terraform modules to configure their S3 backend
# ------------------------------------------------------------------------------

output "tfstate_bucket_name" {
  description = "Name of the S3 bucket storing Terraform state."
  value       = aws_s3_bucket.tfstate.id
}

output "tfstate_bucket_arn" {
  description = "ARN of the S3 bucket storing Terraform state."
  value       = aws_s3_bucket.tfstate.arn
}

output "tfstate_lock_table_name" {
  description = "Name of the DynamoDB table used for state locking."
  value       = aws_dynamodb_table.tfstate_lock.id
}

output "tfstate_kms_key_arn" {
  description = "ARN of the KMS key encrypting state files."
  value       = aws_kms_key.tfstate.arn
}

output "tfstate_kms_alias" {
  description = "Alias of the KMS key encrypting state files."
  value       = aws_kms_alias.tfstate.name
}

output "aws_region" {
  description = "AWS region where the state backend is hosted."
  value       = data.aws_region.current.name
}
