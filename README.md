# terraform-aws-s3

Production-grade AWS S3 bucket module — SSE-KMS encryption, public access
blocked, versioning, TLS-only policy, lifecycle, access logging, CORS,
Object Lock (WORM), and cross-region replication.

Part of the [Devotica Terraform module catalog](https://registry.terraform.io/modules/devotica-labs).

[![CI](https://github.com/devotica-labs/terraform-aws-s3/actions/workflows/ci.yml/badge.svg)](https://github.com/devotica-labs/terraform-aws-s3/actions/workflows/ci.yml)
[![architecture-diagram](https://github.com/devotica-labs/terraform-aws-s3/actions/workflows/architecture-diagram.yml/badge.svg)](https://github.com/devotica-labs/terraform-aws-s3/actions/workflows/architecture-diagram.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)

## Architecture

<!-- BEGIN_ARCH -->
<!-- END_ARCH -->

## Security defaults (all on by default)

| Control | Default | Regulation |
|---|---|---|
| SSE-KMS encryption | ✅ Always on | RBI IT Framework §6.4, PCI-DSS, DPDP |
| S3 Bucket Keys | ✅ Enabled | Cost saving — 99% KMS API reduction |
| Public access blocked | ✅ All 4 settings | CIS AWS Foundations 2.1.1 |
| TLS-only bucket policy | ✅ Always enforced | CIS AWS Foundations 2.1.2 |
| Versioning | ✅ Enabled | RBI audit trail, SOC 2 CC6.1 |
| force_destroy | ❌ false | Data protection — never deletable by accident |

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

## Acknowledgements

This module is purpose-built for Indian fintech workloads. Security
defaults satisfy RBI IT Framework §6.4 (encryption-at-rest), DPDP Act 2023
(personal data encryption), PCI-DSS v4.0 Req 3 and 10 (storage protection
and audit log integrity), and CIS AWS Foundations Benchmark 2.1.1 / 2.1.2.

Governance stack:

- CI: [`devotica-labs/terraform-shared-config`](https://github.com/devotica-labs/terraform-shared-config)
- Policy: [`devotica-labs/terraform-policies`](https://github.com/devotica-labs/terraform-policies)
- Bootstrap: [`devotica-labs/terraform-bootstrap-template`](https://github.com/devotica-labs/terraform-bootstrap-template)

## License

Apache-2.0 — see [LICENSE](LICENSE).
