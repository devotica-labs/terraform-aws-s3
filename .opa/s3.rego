# OPA policy for terraform-aws-s3-bucket
# Enforces fintech-grade S3 security defaults in CI
# All rules are DENY — violations block PR merge

package main

# ---------------------------------------------------------------------------
# Rule 1: Mandatory tags on S3 bucket
# ---------------------------------------------------------------------------
required_tags := {"ManagedBy", "Module"}

deny[msg] {
  r := input.resource_changes[_]
  r.type == "aws_s3_bucket"
  r.change.after != null
  tag := required_tags[_]
  not r.change.after.tags[tag]
  msg := sprintf(
    "DENY: S3 bucket %v is missing required tag: %v",
    [r.address, tag]
  )
}

# ---------------------------------------------------------------------------
# Rule 2: Public access must be fully blocked
# ---------------------------------------------------------------------------
deny[msg] {
  r := input.resource_changes[_]
  r.type == "aws_s3_bucket_public_access_block"
  r.change.after != null
  r.change.after.block_public_acls == false
  msg := sprintf(
    "DENY: %v — block_public_acls must be true (OPA 02_no_public_s3)",
    [r.address]
  )
}

deny[msg] {
  r := input.resource_changes[_]
  r.type == "aws_s3_bucket_public_access_block"
  r.change.after != null
  r.change.after.block_public_policy == false
  msg := sprintf(
    "DENY: %v — block_public_policy must be true (OPA 02_no_public_s3)",
    [r.address]
  )
}

# ---------------------------------------------------------------------------
# Rule 3: SSE-KMS encryption required — no SSE-S3 allowed in fintech
# ---------------------------------------------------------------------------
deny[msg] {
  r := input.resource_changes[_]
  r.type == "aws_s3_bucket_server_side_encryption_configuration"
  r.change.after != null
  rule := r.change.after.rule[_]
  rule.apply_server_side_encryption_by_default[_].sse_algorithm != "aws:kms"
  msg := sprintf(
    "DENY: %v — SSE algorithm must be aws:kms, not AES256 (OPA 03_encryption_required)",
    [r.address]
  )
}

# ---------------------------------------------------------------------------
# Rule 4: force_destroy must never be true — warn loudly
# ---------------------------------------------------------------------------
warn[msg] {
  r := input.resource_changes[_]
  r.type == "aws_s3_bucket"
  r.change.after != null
  r.change.after.force_destroy == true
  msg := sprintf(
    "WARN: %v — force_destroy = true. This will delete all objects when the bucket is destroyed. NEVER use in prod.",
    [r.address]
  )
}
