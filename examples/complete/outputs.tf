output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = module.s3_bucket.bucket_arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name of the bucket."
  value       = module.s3_bucket.bucket_regional_domain_name
}

output "replication_role_arn" {
  description = "ARN of the replication IAM role."
  value       = module.s3_bucket.replication_role_arn
}
