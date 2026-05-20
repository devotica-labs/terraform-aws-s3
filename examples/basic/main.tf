# Basic example — minimum required inputs
# SSE-KMS encryption, public access blocked, versioning on, TLS-only policy
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

  name        = "my-company-documents"
  kms_key_arn = "arn:aws:kms:ap-south-1:123456789012:key/mrk-xxxxxxxx"

  tags = {
    Environment = "sandbox"
    Project     = "my-project"
    Owner       = "platform@mycompany.com"
    CostCenter  = "PLATFORM"
    ManagedBy   = "terraform"
    Repo        = "github.com/mycompany/infra"
  }
}
