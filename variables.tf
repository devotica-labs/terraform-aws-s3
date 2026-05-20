# ---------------------------------------------------------------------------
# REQUIRED
# ---------------------------------------------------------------------------

variable "name" {
  description = "Logical name for the bucket. Used as bucket name and resource prefix."
  type        = string
  validation {
    condition     = length(var.name) >= 3 && length(var.name) <= 63 && can(regex("^[a-z0-9][a-z0-9\\-]*[a-z0-9]$", var.name))
    error_message = "name must be 3–63 characters, lowercase alphanumeric and hyphens only, no leading/trailing hyphens."
  }
}

# ---------------------------------------------------------------------------
# ENCRYPTION — fintech defaults: KMS always on
# ---------------------------------------------------------------------------

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for SSE-KMS encryption. Required — no plaintext S3 in fintech."
  type        = string
  validation {
    condition     = can(regex("^arn:aws:kms:", var.kms_key_arn))
    error_message = "kms_key_arn must be a valid KMS key ARN starting with arn:aws:kms:"
  }
}

variable "bucket_key_enabled" {
  description = "Enable S3 Bucket Keys to reduce KMS API calls and costs by up to 99%."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# VERSIONING
# ---------------------------------------------------------------------------

variable "versioning_enabled" {
  description = "Enable bucket versioning. Required for state buckets and audit-grade fintech storage."
  type        = bool
  default     = true
}

variable "mfa_delete" {
  description = "Require MFA to permanently delete object versions. Enable in prod for highest-sensitivity buckets."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# LIFECYCLE
# ---------------------------------------------------------------------------

variable "noncurrent_version_expiry_days" {
  description = "Days before noncurrent object versions are permanently deleted. 0 disables expiry."
  type        = number
  default     = 90
  validation {
    condition     = var.noncurrent_version_expiry_days >= 0
    error_message = "noncurrent_version_expiry_days must be 0 or a positive integer."
  }
}

variable "transition_to_ia_days" {
  description = "Days before current objects transition to S3 Standard-IA. 0 disables transition."
  type        = number
  default     = 30
  validation {
    condition     = var.transition_to_ia_days >= 0
    error_message = "transition_to_ia_days must be 0 or a positive integer."
  }
}

variable "transition_to_glacier_days" {
  description = "Days before current objects transition to S3 Glacier Instant Retrieval. 0 disables transition."
  type        = number
  default     = 90
  validation {
    condition     = var.transition_to_glacier_days >= 0
    error_message = "transition_to_glacier_days must be 0 or a positive integer."
  }
}

variable "expiry_days" {
  description = "Days before current objects are permanently deleted. 0 disables expiry (recommended for audit logs)."
  type        = number
  default     = 0
  validation {
    condition     = var.expiry_days >= 0
    error_message = "expiry_days must be 0 or a positive integer."
  }
}

# ---------------------------------------------------------------------------
# ACCESS LOGGING
# ---------------------------------------------------------------------------

variable "logging_target_bucket" {
  description = "Bucket name to receive server access logs. Leave empty to disable access logging."
  type        = string
  default     = ""
}

variable "logging_target_prefix" {
  description = "Prefix for access log objects in the target bucket."
  type        = string
  default     = "s3-access-logs/"
}

# ---------------------------------------------------------------------------
# CORS
# ---------------------------------------------------------------------------

variable "cors_rules" {
  description = "List of CORS rules. Leave empty to disable CORS."
  type = list(object({
    allowed_headers = optional(list(string), ["*"])
    allowed_methods = list(string)
    allowed_origins = list(string)
    expose_headers  = optional(list(string), [])
    max_age_seconds = optional(number, 3600)
  }))
  default = []
}

# ---------------------------------------------------------------------------
# INTELLIGENT TIERING
# ---------------------------------------------------------------------------

variable "intelligent_tiering_enabled" {
  description = "Enable S3 Intelligent-Tiering for automatic cost optimisation."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# OBJECT LOCK (WORM) — for compliance/audit use cases
# ---------------------------------------------------------------------------

variable "object_lock_enabled" {
  description = "Enable S3 Object Lock (WORM). Cannot be disabled after bucket creation. Required for some RBI/SEBI audit mandates."
  type        = bool
  default     = false
}

variable "object_lock_mode" {
  description = "Object Lock retention mode: GOVERNANCE (admin can override) or COMPLIANCE (no override, ever)."
  type        = string
  default     = "GOVERNANCE"
  validation {
    condition     = contains(["GOVERNANCE", "COMPLIANCE"], var.object_lock_mode)
    error_message = "object_lock_mode must be GOVERNANCE or COMPLIANCE."
  }
}

variable "object_lock_days" {
  description = "Number of days for Object Lock default retention. 0 means no default retention period."
  type        = number
  default     = 0
}

# ---------------------------------------------------------------------------
# REPLICATION (cross-region DR — required for fintech prod)
# ---------------------------------------------------------------------------

variable "replication_enabled" {
  description = "Enable cross-region replication to a DR bucket. Required for RBI data durability mandates in prod."
  type        = bool
  default     = false
}

variable "replication_destination_bucket_arn" {
  description = "ARN of the destination bucket for cross-region replication."
  type        = string
  default     = ""
}

variable "replication_destination_kms_key_arn" {
  description = "ARN of the KMS key in the destination region for encrypted replication."
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------
# FORCE DESTROY
# ---------------------------------------------------------------------------

variable "force_destroy" {
  description = "Allow bucket deletion even when it contains objects. NEVER true in prod. Safe for sandbox/test."
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# TAGS
# ---------------------------------------------------------------------------

variable "tags" {
  description = "Map of tags applied to all resources. Merged with mandatory Devotica tags."
  type        = map(string)
  default     = {}
}
