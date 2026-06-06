locals {
  # Tag map merged on every resource
  tags = merge(var.tags, {
    ManagedBy = "terraform"
    Module    = "devotica-labs/s3/aws"
  })

  # Lifecycle rules are only meaningful when versioning is on
  versioning_status = var.versioning_enabled ? "Enabled" : "Suspended"

  # Replication requires versioning
  replication_active = var.replication_enabled && var.versioning_enabled

  # Logging enabled when target bucket provided
  logging_enabled = length(var.logging_target_bucket) > 0

  # Object lock requires versioning
  object_lock_active = var.object_lock_enabled && var.object_lock_days > 0
}
