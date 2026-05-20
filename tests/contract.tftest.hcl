# Contract tests — locks the output API surface

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
  name        = "contract-test"
  kms_key_arn = "arn:aws:kms:ap-south-1:123456789012:key/mrk-contract"
}

# Contract: bucket is planned
run "one_bucket_created" {
  command = plan
  assert {
    condition     = aws_s3_bucket.this.bucket == "contract-test"
    error_message = "exactly one S3 bucket must be planned with the correct name"
  }
}

# Contract: public access block is always planned
run "public_access_block_always_present" {
  command = plan
  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls == true
    error_message = "public access block must always be planned"
  }
}

# Contract: SSE-KMS encryption always planned
run "encryption_always_present" {
  command = plan
  assert {
    condition = tolist(
      aws_s3_bucket_server_side_encryption_configuration.this.rule
    )[0].apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "SSE-KMS encryption must always be planned"
  }
}

# Contract: replication role absent when disabled
run "replication_role_absent_when_disabled" {
  command = plan
  assert {
    condition     = length(aws_iam_role.replication) == 0
    error_message = "replication IAM role must not exist when replication_enabled = false"
  }
}

# Contract: versioning enabled by default
run "versioning_on_by_default" {
  command = plan
  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "versioning must default to Enabled"
  }
}
