# ---------------------------------------------------------------------------
# S3 Bucket — fintech-grade defaults
# RBI / DPDP / PCI-DSS / SOC 2 / CIS AWS Foundations Benchmark
#
# Security defaults (ALL on by default):
#   - SSE-KMS encryption (no plaintext, ever)
#   - S3 Bucket Keys (cost optimisation, 99% KMS call reduction)
#   - Public access fully blocked (all 4 settings)
#   - Versioning enabled
#   - TLS-only bucket policy
#   - Server access logging (when target bucket provided)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "this" {
  bucket        = var.name
  force_destroy = var.force_destroy

  # Object Lock requires being set at creation time
  dynamic "object_lock_configuration" {
    for_each = var.object_lock_enabled ? [1] : []
    content {
      object_lock_enabled = "Enabled"
    }
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Block ALL public access — non-negotiable for fintech
# OPA policy 02_no_public_s3.rego enforces this in CI
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------------------------------------------------------------------------
# SSE-KMS encryption — customer-managed key required
# OPA policy 03_encryption_required.rego enforces this in CI
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.bucket_key_enabled
  }
}

# ---------------------------------------------------------------------------
# Versioning
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status     = local.versioning_status
    mfa_delete = var.mfa_delete ? "Enabled" : "Disabled"
  }
}

# ---------------------------------------------------------------------------
# Bucket policy — deny non-TLS requests (CIS AWS 2.1.2)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "tls_only" {
  statement {
    sid    = "DenyNonTLS"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]

    resources = [
      aws_s3_bucket.this.arn,
      "${aws_s3_bucket.this.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket     = aws_s3_bucket.this.id
  policy     = data.aws_iam_policy_document.tls_only.json
  depends_on = [aws_s3_bucket_public_access_block.this]
}

# ---------------------------------------------------------------------------
# Lifecycle rules
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = var.versioning_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  depends_on = [aws_s3_bucket_versioning.this]

  rule {
    id     = "noncurrent-version-expiry"
    status = var.noncurrent_version_expiry_days > 0 ? "Enabled" : "Disabled"

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiry_days > 0 ? var.noncurrent_version_expiry_days : 1
    }
  }

  rule {
    id     = "transition-to-ia"
    status = var.transition_to_ia_days > 0 ? "Enabled" : "Disabled"

    transition {
      days          = var.transition_to_ia_days > 0 ? var.transition_to_ia_days : 1
      storage_class = "STANDARD_IA"
    }
  }

  rule {
    id     = "transition-to-glacier"
    status = var.transition_to_glacier_days > 0 ? "Enabled" : "Disabled"

    transition {
      days          = var.transition_to_glacier_days > 0 ? var.transition_to_glacier_days : 1
      storage_class = "GLACIER_IR"
    }
  }

  rule {
    id     = "current-version-expiry"
    status = var.expiry_days > 0 ? "Enabled" : "Disabled"

    expiration {
      days = var.expiry_days > 0 ? var.expiry_days : 1
    }
  }

  rule {
    id     = "abort-incomplete-multipart-upload"
    status = "Enabled"

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# ---------------------------------------------------------------------------
# Server access logging
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_logging" "this" {
  count  = local.logging_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id

  target_bucket = var.logging_target_bucket
  target_prefix = var.logging_target_prefix
}

# ---------------------------------------------------------------------------
# CORS
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_cors_configuration" "this" {
  count  = length(var.cors_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "cors_rule" {
    for_each = var.cors_rules
    content {
      allowed_headers = cors_rule.value.allowed_headers
      allowed_methods = cors_rule.value.allowed_methods
      allowed_origins = cors_rule.value.allowed_origins
      expose_headers  = cors_rule.value.expose_headers
      max_age_seconds = cors_rule.value.max_age_seconds
    }
  }
}

# ---------------------------------------------------------------------------
# Intelligent Tiering
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_intelligent_tiering_configuration" "this" {
  count  = var.intelligent_tiering_enabled ? 1 : 0
  bucket = aws_s3_bucket.this.id
  name   = "${var.name}-tiering"
  status = "Enabled"

  tiering {
    access_tier = "DEEP_ARCHIVE_ACCESS"
    days        = 180
  }

  tiering {
    access_tier = "ARCHIVE_ACCESS"
    days        = 90
  }
}

# ---------------------------------------------------------------------------
# Object Lock default retention
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_object_lock_configuration" "this" {
  count  = local.object_lock_active ? 1 : 0
  bucket = aws_s3_bucket.this.id

  rule {
    default_retention {
      mode = var.object_lock_mode
      days = var.object_lock_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.this]
}

# ---------------------------------------------------------------------------
# Cross-region replication (DR)
# ---------------------------------------------------------------------------

resource "aws_iam_role" "replication" {
  count = local.replication_active ? 1 : 0
  name  = "${var.name}-s3-replication"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "replication" {
  count = local.replication_active ? 1 : 0
  name  = "${var.name}-s3-replication"
  role  = aws_iam_role.replication[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetReplicationConfiguration",
          "s3:ListBucket",
        ]
        Resource = aws_s3_bucket.this.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObjectVersionForReplication",
          "s3:GetObjectVersionAcl",
          "s3:GetObjectVersionTagging",
        ]
        Resource = "${aws_s3_bucket.this.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
        ]
        Resource = "${var.replication_destination_bucket_arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
        ]
        Resource = var.kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey",
        ]
        Resource = var.replication_destination_kms_key_arn
      },
    ]
  })
}

resource "aws_s3_bucket_replication_configuration" "this" {
  count  = local.replication_active ? 1 : 0
  bucket = aws_s3_bucket.this.id
  role   = aws_iam_role.replication[0].arn

  depends_on = [aws_s3_bucket_versioning.this]

  rule {
    id     = "full-replication"
    status = "Enabled"

    source_selection_criteria {
      sse_kms_encrypted_objects {
        status = "Enabled"
      }
    }

    destination {
      bucket        = var.replication_destination_bucket_arn
      storage_class = "STANDARD"

      encryption_configuration {
        replica_kms_key_id = var.replication_destination_kms_key_arn
      }
    }
  }
}

# ---------------------------------------------------------------------------
# Event notifications (optional — CKV2_AWS_62)
# Disabled by default. Enable via notification_queue_arn variable.
# ---------------------------------------------------------------------------

resource "aws_s3_bucket_notification" "this" {
  count  = length(var.notification_queue_arn) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  queue {
    id        = "all-events"
    queue_arn = var.notification_queue_arn
    events    = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }
}
