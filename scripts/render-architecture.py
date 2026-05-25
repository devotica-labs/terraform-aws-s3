#!/usr/bin/env python3
"""Render an AWS architecture diagram from a Terraform plan JSON.

Reads the output of `terraform show -json plan.binary` from the
`examples/complete/` plan, maps each planned AWS resource to its
`diagrams.aws.*` icon, groups subnets by availability zone and tier
(public / private), and writes a PNG.

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
import re
import sys
from collections import defaultdict
from pathlib import Path

from diagrams import Cluster, Diagram, Edge
from diagrams.aws.management import Cloudwatch
from diagrams.aws.network import (
    InternetGateway,
    NATGateway,
    PrivateSubnet,
    PublicSubnet,
    RouteTable,
    VPC,
    VPCFlowLogs,
)
from diagrams.aws.security import IAMRole


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

    vpcs = by_type.get("aws_vpc", [])
    if not vpcs:
        raise SystemExit("No aws_vpc resource found in plan — nothing to render.")

    vpc_v = values(vpcs[0])
    vpc_name = vpc_v.get("tags", {}).get("Name") or "vpc"
    vpc_cidr = vpc_v.get("cidr_block", "(no cidr)")

    igws = by_type.get("aws_internet_gateway", [])
    nat_gws = by_type.get("aws_nat_gateway", [])

    # Bucket subnets per AZ, per tier. The vpc module names them
    # aws_subnet.public["az"] and aws_subnet.private["az"], so we
    # disambiguate on the resource address.
    public_by_az: dict[str, list[dict]] = defaultdict(list)
    private_by_az: dict[str, list[dict]] = defaultdict(list)
    for r in by_type.get("aws_subnet", []):
        az = values(r).get("availability_zone") or "unknown"
        if ".public" in r["address"]:
            public_by_az[az].append(r)
        elif ".private" in r["address"]:
            private_by_az[az].append(r)

    all_azs = sorted(set(public_by_az.keys()) | set(private_by_az.keys()))

    nat_by_az: dict[str, dict] = {}
    for ng in nat_gws:
        # Module addresses NAT gateways via aws_nat_gateway.this["az"]
        m = re.search(r'\["([^"]+)"\]', ng["address"])
        if m:
            nat_by_az[m.group(1)] = ng

    has_flow_logs = bool(by_type.get("aws_flow_log"))
    has_log_group = bool(by_type.get("aws_cloudwatch_log_group"))
    has_flow_log_role = any(
        ".flow_logs" in r["address"] for r in by_type.get("aws_iam_role", [])
    )

    # ------------------------------------------------------------------------
    # Diagram
    # ------------------------------------------------------------------------
    graph_attr = {
        "fontsize": "20",
        "splines": "ortho",
        "ranksep": "0.9",
        "nodesep": "0.45",
        "pad": "0.5",
    }
    out_no_ext.parent.mkdir(parents=True, exist_ok=True)
    with Diagram(
        f"terraform-aws-vpc — {vpc_name}  ({vpc_cidr})",
        filename=str(out_no_ext),
        show=False,
        direction="TB",
        outformat="png",
        graph_attr=graph_attr,
    ):
        with Cluster(f"VPC  {vpc_cidr}"):
            igw_node = InternetGateway("Internet\nGateway") if igws else None

            # Public route table fan-in target.
            public_rt = None
            for r in by_type.get("aws_route_table", []):
                if ".public" in r["address"]:
                    public_rt = RouteTable("Public RT\n→ IGW")
                    break

            # One AZ cluster per zone. Within each cluster: public subnet,
            # NAT (if present), private subnet, private RT.
            for az in all_azs:
                with Cluster(f"AZ  {az}"):
                    pub_nodes = []
                    for s in public_by_az.get(az, []):
                        cidr = values(s).get("cidr_block", "")
                        pub_nodes.append(PublicSubnet(f"Public\n{cidr}"))

                    az_nat_node = None
                    if az in nat_by_az:
                        az_nat_node = NATGateway(f"NAT GW\n{az[-1]}")

                    priv_nodes = []
                    for s in private_by_az.get(az, []):
                        cidr = values(s).get("cidr_block", "")
                        priv_nodes.append(PrivateSubnet(f"Private\n{cidr}"))

                    # Private subnet → NAT for egress
                    if az_nat_node:
                        for p in priv_nodes:
                            p >> Edge(label="egress") >> az_nat_node

                    # NAT → public RT (lives in public subnet at apply time)
                    if az_nat_node and public_rt:
                        az_nat_node >> Edge(style="dashed") >> public_rt

                    # Public subnet → public RT
                    if public_rt:
                        for p in pub_nodes:
                            p >> public_rt

            # Public RT → IGW
            if public_rt and igw_node:
                public_rt >> Edge(label="0.0.0.0/0") >> igw_node

            # Observability sidecar
            if has_flow_logs:
                with Cluster("Observability"):
                    flow_log_node = VPCFlowLogs("VPC Flow Logs")
                    if has_log_group:
                        flow_log_node >> Cloudwatch("CloudWatch\nLog Group")
                    if has_flow_log_role:
                        IAMRole("Flow Logs\nIAM Role")


def main() -> None:
    if len(sys.argv) < 3:
        sys.stderr.write(
            "Usage: render-architecture.py <plan.json> <output-path-without-ext>\n"
        )
        sys.exit(2)
    render(Path(sys.argv[1]), Path(sys.argv[2]))


if __name__ == "__main__":
    main()
