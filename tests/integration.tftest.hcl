# Integration tests — apply + assert + destroy.
# Requires real AWS credentials. Triggered via workflow_dispatch on integration.yml.
# Run manually: terraform test -filter=tests/integration.tftest.hcl

provider "aws" {
  region = "ap-south-1"
}

variables {
  name        = "integ-test-s3"
  kms_key_arn = "arn:aws:kms:ap-south-1:911526871324:key/fef997b5-160e-4af8-be46-d733360fefe9"
  force_destroy = true   # allow cleanup after test
  tags = {
    Environment = "integration-test"
    Ephemeral   = "true"
  }
}

run "apply_and_assert" {
  command = apply

  assert {
    condition     = aws_s3_bucket.this.id != ""
    error_message = "S3 bucket was not created."
  }
  assert {
    condition     = aws_s3_bucket_public_access_block.this.block_public_acls == true
    error_message = "Public access must be blocked."
  }
  assert {
    condition     = tolist(aws_s3_bucket_server_side_encryption_configuration.this.rule)[0].apply_server_side_encryption_by_default[0].sse_algorithm == "aws:kms"
    error_message = "Encryption must be aws:kms."
  }
  assert {
    condition     = aws_s3_bucket_versioning.this.versioning_configuration[0].status == "Enabled"
    error_message = "Versioning must be enabled."
  }
}
