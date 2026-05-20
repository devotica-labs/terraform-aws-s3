# terraform-aws-s3-bucket

Production-grade AWS S3 bucket module with fintech-grade security defaults.
Built for Indian fintech workloads — RBI, DPDP, PCI-DSS, SOC 2, CIS AWS Foundations Benchmark.

Part of the [Devotica Terraform module catalog](https://registry.terraform.io/modules/devotica-labs).

[![CI](https://github.com/devotica-labs/terraform-aws-s3-bucket/actions/workflows/ci.yml/badge.svg)](https://github.com/devotica-labs/terraform-aws-s3-bucket/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

## Security defaults (all on by default)

| Control | Default | Regulation |
|---|---|---|
| SSE-KMS encryption | ✅ Always on | RBI, PCI-DSS, DPDP |
| S3 Bucket Keys | ✅ Enabled | Cost saving |
| Public access blocked | ✅ All 4 settings | CIS AWS 2.1.1 |
| TLS-only bucket policy | ✅ Always enforced | CIS AWS 2.1.2 |
| Versioning | ✅ Enabled | RBI audit trail |

## Usage

### Basic

```hcl
module "s3_bucket" {
  source  = "devotica-labs/s3-bucket/aws"
  version = "~> 1.0"

  name        = "my-company-documents"
  kms_key_arn = "arn:aws:kms:ap-south-1:123456789012:key/mrk-xxxxxxxx"

  tags = {
    Environment = "prod"
    Project     = "my-project"
    Owner       = "platform@company.com"
    CostCenter  = "PLATFORM"
    Repo        = "github.com/company/infra"
  }
}
```

### With replication (RBI DR mandate)

```hcl
module "s3_bucket" {
  source  = "devotica-labs/s3-bucket/aws"
  version = "~> 1.0"

  name        = "paywolrd-prod-documents"
  kms_key_arn = "arn:aws:kms:ap-south-1:123456789012:key/mrk-primary"

  replication_enabled                 = true
  replication_destination_bucket_arn  = "arn:aws:s3:::paywolrd-dr-documents"
  replication_destination_kms_key_arn = "arn:aws:kms:ap-south-2:123456789012:key/mrk-dr"

  tags = { ... }
}
```

## How to use with devotica-sandbox-bootstrap

The bootstrap creates the KMS key you pass to this module:

```hcl
# In your infra repo:
module "s3_bucket" {
  source  = "devotica-labs/s3-bucket/aws"
  version = "~> 1.0"

  name        = "my-bucket"
  kms_key_arn = var.kms_key_arn   # ← comes from TF_KMS_KEY_ARN GitHub variable
                                   #   set after running bootstrap
}
```

```hcl
# In your tfvars:
kms_key_arn = "arn:aws:kms:ap-south-1:911526871324:key/fef997b5-..."
# ← value from: terraform output kms_key_arn (on devotica-sandbox-bootstrap)
```

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

## License

Apache-2.0 — see [LICENSE](LICENSE).
