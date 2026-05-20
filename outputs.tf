output "bucket_id" {
  description = "Name (ID) of the S3 bucket."
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN of the S3 bucket."
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Bucket domain name — e.g. bucket.s3.amazonaws.com."
  value       = aws_s3_bucket.this.bucket_domain_name
}

output "bucket_regional_domain_name" {
  description = "Bucket regional domain name — e.g. bucket.s3.ap-south-1.amazonaws.com."
  value       = aws_s3_bucket.this.bucket_regional_domain_name
}

output "bucket_region" {
  description = "AWS region where the bucket resides."
  value       = aws_s3_bucket.this.region
}

output "bucket_hosted_zone_id" {
  description = "Route 53 hosted zone ID of the bucket — used for alias records."
  value       = aws_s3_bucket.this.hosted_zone_id
}

output "replication_role_arn" {
  description = "ARN of the IAM role used for cross-region replication. Empty when replication_enabled = false."
  value       = local.replication_active ? aws_iam_role.replication[0].arn : ""
}
