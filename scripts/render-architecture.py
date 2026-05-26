#!/usr/bin/env python3
"""Render an AWS architecture diagram from a Terraform plan JSON.

Reads the output of `terraform show -json plan.binary` from the
`examples/complete/` plan, maps each planned AWS resource to its
`diagrams.aws.*` icon, and writes a PNG.

This script is invoked from `.github/workflows/architecture-diagram.yml`
on every PR and on push to main. The committed PNG lives at
`docs/architecture.png` and is embedded in README.md between
`<!-- BEGIN_ARCH -->` / `<!-- END_ARCH -->` markers.

Usage:
    python scripts/render-architecture.py <plan.json> <output-path-no-ext>

Example:
    python scripts/render-architecture.py examples/complete/plan.json docs/architecture
        -> writes docs/architecture.png
"""

from __future__ import annotations

import json
import sys
from collections import defaultdict
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.storage import S3
from diagrams.aws.security import KMS
from diagrams.aws.management import Cloudwatch
from diagrams.aws.general import General


# ----------------------------------------------------------------------------
# Resource collection
# ----------------------------------------------------------------------------


def load_resources(plan_path: Path) -> list[dict]:
    """Flatten every resource (root + child modules) from a Terraform plan JSON."""
    plan = json.loads(plan_path.read_text())
    root = plan.get("planned_values", {}).get("root_module", {})
    collected: list[dict] = []

    def walk(mod: dict) -> None:
        for r in mod.get("resources", []):
            collected.append(r)
        for child in mod.get("child_modules", []):
            walk(child)

    walk(root)
    return collected


def values(r: dict) -> dict:
    return r.get("values", {}) or {}


# ----------------------------------------------------------------------------
# Render
# ----------------------------------------------------------------------------


def render(plan_path: Path, out_no_ext: Path) -> None:
    resources = load_resources(plan_path)
    by_type: dict[str, list[dict]] = defaultdict(list)
    for r in resources:
        by_type[r["type"]].append(r)

    buckets = by_type.get("aws_s3_bucket", [])
    if not buckets:
        raise SystemExit("No aws_s3_bucket resource found in plan — nothing to render.")

    bucket_v = values(buckets[0])
    bucket_name = bucket_v.get("bucket") or "s3-bucket"

    has_versioning   = bool(by_type.get("aws_s3_bucket_versioning"))
    has_encryption   = bool(by_type.get("aws_s3_bucket_server_side_encryption_configuration"))
    has_public_block = bool(by_type.get("aws_s3_bucket_public_access_block"))
    has_policy       = bool(by_type.get("aws_s3_bucket_policy"))
    has_lifecycle    = bool(by_type.get("aws_s3_bucket_lifecycle_configuration"))
    has_logging      = bool(by_type.get("aws_s3_bucket_logging"))
    has_replication  = bool(by_type.get("aws_s3_bucket_replication_configuration"))
    has_object_lock  = bool(by_type.get("aws_s3_bucket_object_lock_configuration"))
    has_cors         = bool(by_type.get("aws_s3_bucket_cors_configuration"))
    has_tiering      = bool(by_type.get("aws_s3_bucket_intelligent_tiering_configuration"))
    has_iam_role     = bool(by_type.get("aws_iam_role"))

    graph_attr = {
        "fontsize": "20",
        "splines": "ortho",
        "ranksep": "0.9",
        "nodesep": "0.45",
        "pad": "0.5",
    }

    out_no_ext.parent.mkdir(parents=True, exist_ok=True)

    with Diagram(
        f"terraform-aws-s3 — {bucket_name}",
        filename=str(out_no_ext),
        show=False,
        direction="TB",
        outformat="png",
        graph_attr=graph_attr,
    ):
        kms = KMS("KMS Key\n(external)\nkms_key_arn")
        bucket = S3(f"S3 Bucket\n{bucket_name}")

        kms >> Edge(label="encrypts") >> bucket

        with Cluster("Security Controls (always on)"):
            nodes = []
            if has_public_block:
                nodes.append(General("public_access_block\nall 4 = true"))
            if has_encryption:
                nodes.append(General("server_side_encryption\naws:kms"))
            if has_policy:
                nodes.append(General("bucket_policy\nDenyNonTLS"))
            if has_versioning:
                nodes.append(General("versioning\nEnabled"))
            for n in nodes:
                bucket >> Edge(label="enforces") >> n

        optional = []
        if has_lifecycle:
            optional.append(General("lifecycle\nIA → Glacier → Expire"))
        if has_logging:
            optional.append(General("bucket_logging\naccess logs"))
        if has_object_lock:
            optional.append(General("object_lock\nWORM"))
        if has_cors:
            optional.append(General("cors_configuration"))
        if has_tiering:
            optional.append(General("intelligent_tiering\ncost opt"))

        if optional:
            with Cluster("Optional Features"):
                for n in optional:
                    bucket >> Edge(label="optional") >> n

        if has_logging:
            cw = Cloudwatch("CloudWatch\nlogs target")
            bucket >> Edge(label="sends logs to") >> cw

        if has_replication and has_iam_role:
            with Cluster("Cross-Region DR"):
                dr = S3("DR Bucket\n(destination)")
                repl_role = General("IAM Role\nreplication")
                bucket >> Edge(label="replicates to") >> dr
                repl_role >> Edge(label="assumes") >> dr


def main() -> None:
    if len(sys.argv) < 3:
        sys.stderr.write(
            "Usage: render-architecture.py <plan.json> <output-path-without-ext>\n"
        )
        sys.exit(2)
    render(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
