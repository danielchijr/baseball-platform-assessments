output "landing_bucket_arn" {
  description = "The ARN of the landing S3 bucket"
  value       = aws_s3_bucket.landing.arn
}

output "curated_bucket_arn" {
  description = "The ARN of the curated S3 bucket"
  value       = aws_s3_bucket.curated.arn
}

output "kms_key_arn" {
  description = "The ARN of the KMS key for S3 encryption"
  value       = aws_kms_key.s3_key.arn
}

output "databricks_role_arn" {
  description = "The ARN of the IAM role for Databricks jobs"
  value       = aws_iam_role.databricks_job_role.arn
}
