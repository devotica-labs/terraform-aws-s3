# Unit tests — plan only, no AWS credentials needed
# Mock provider so tests run in CI without OIDC

mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = { account_id = "123456789012" }
  }
  mock_data "aws_partition" {
    defaults = { partition = "aws" }
  }
  mock_data "aws_region" {
    defaults = { name = "ap-south-1" }
  }
}

variables {
  name        = "test-bucket"
  kms_key_arn = "arn:aws:kms:ap-south-1:123456789012:key/mrk-test"
}

# Test 1: Bucket created with correct name
run "bucket_name" {
  command = plan
  assert {
    condition     = aws_s3_bucket.this.bucket == "test-bucket"
    error_message = "bucket name must match var.name"
  }
}

# Test 2: Public access fully blocked
run "public_access_blocked" {
  command = plan
  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls == true
    error_message = "block_public_acls must be true"
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_policy == true
    error_message = "block_public_policy must be true"
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.this.ignore_public_acls == true
    error_message = "ignore_public_acls must be true"
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.this.restrict_public_buckets == true
    error_message = "restrict_public_buckets must be true"
  }
}

# Test 3: KMS encryption configured
# Fix: rule is a set — use tolist() to index by position
run "kms_encryption" {
  command = plan
  assert {
    condition = tolist(
      aws_s3_bucket_server_side_encryption_configuration.this.rule
    )[0].apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "SSE algorithm must be aws:kms"
  }
  assert {
    condition = tolist(
      aws_s3_bucket_server_side_encryption_configuration.this.rule
    )[0].apply_server_side_encryption_by_default[0].kms_master_key_id == "arn:aws:kms:ap-south-1:123456789012:key/mrk-test"
    error_message = "KMS key ARN must match var.kms_key_arn"
  }
}

# Test 4: Bucket key enabled by default (cost saving)
run "bucket_key_enabled" {
  command = plan
  assert {
    condition = tolist(
      aws_s3_bucket_server_side_encryption_configuration.this.rule
    )[0].bucket_key_enabled == true
    error_message = "bucket_key_enabled must default to true"
  }
}

# Test 5: Versioning enabled by default
run "versioning_enabled" {
  command = plan
  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "versioning must be Enabled by default"
  }
}

# Test 6: Versioning disabled when set to false
run "versioning_disabled" {
  command = plan
  variables {
    versioning_enabled = false
  }
  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Suspended"
    error_message = "versioning must be Suspended when versioning_enabled = false"
  }
}

# Test 7: Force destroy is false by default
run "force_destroy_default_false" {
  command = plan
  assert {
    condition     = aws_s3_bucket.this.force_destroy == false
    error_message = "force_destroy must default to false"
  }
}

# Test 8: No replication role when replication disabled
run "no_replication_by_default" {
  command = plan
  assert {
    condition     = length(aws_iam_role.replication) == 0
    error_message = "replication IAM role must not be created when replication_enabled = false"
  }
}

# Test 9: No logging by default
run "no_logging_by_default" {
  command = plan
  assert {
    condition     = length(aws_s3_bucket_logging.this) == 0
    error_message = "logging must not be created when logging_target_bucket is empty"
  }
}

# Test 10: Logging created when target bucket provided
run "logging_when_target_set" {
  command = plan
  variables {
    logging_target_bucket = "my-log-bucket"
  }
  assert {
    condition     = length(aws_s3_bucket_logging.this) == 1
    error_message = "logging must be created when logging_target_bucket is set"
  }
}
