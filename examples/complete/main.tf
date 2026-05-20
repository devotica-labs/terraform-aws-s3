# Complete example — all variables exercised
# Fintech prod-grade: KMS, versioning, lifecycle, logging, replication
#
# NOTE: uses local path during development.
# Change to Registry source after v1.0.0 is published:
#   source  = "devotica-labs/s3/aws"
#   version = "~> 1.0"

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.44"
    }
  }
}

module "s3_bucket" {
  source = "../.."

  name        = "my-company-prod-documents"
  kms_key_arn = "arn:aws:kms:ap-south-1:123456789012:key/mrk-xxxxxxxx"

  versioning_enabled             = true
  mfa_delete                     = false
  transition_to_ia_days          = 30
  transition_to_glacier_days     = 90
  noncurrent_version_expiry_days = 365
  expiry_days                    = 0

  logging_target_bucket = "my-company-prod-access-logs"
  logging_target_prefix = "s3-access-logs/documents/"

  replication_enabled                 = true
  replication_destination_bucket_arn  = "arn:aws:s3:::my-company-dr-documents"
  replication_destination_kms_key_arn = "arn:aws:kms:ap-south-2:123456789012:key/mrk-yyyyyyyy"

  object_lock_enabled = false
  object_lock_mode    = "GOVERNANCE"
  object_lock_days    = 0

  intelligent_tiering_enabled = true
  bucket_key_enabled          = true
  force_destroy               = false

  tags = {
    Environment = "production"
    Project     = "my-project"
    Owner       = "platform@mycompany.com"
    CostCenter  = "PLATFORM-PROD"
    ManagedBy   = "terraform"
    Repo        = "github.com/mycompany/infra"
  }
}
