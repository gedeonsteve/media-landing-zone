# Media Landing Zone

> Production-grade AWS multi-account landing zone for media broadcast operations, built with Terraform.

[![Terraform](https://img.shields.io/badge/Terraform-1.9+-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Organizations-FF9900?logo=amazonaws&logoColor=white)](https://aws.amazon.com/organizations/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

## Overview

This project implements a complete AWS multi-account landing zone designed for media broadcast operations. It provides the organizational foundation that broadcasters and media companies use to operate hundreds of channels across isolated AWS accounts, with cost allocation, security guardrails, centralized logging, and automated account vending.

The architecture follows AWS Well-Architected best practices for multi-account strategy and is fully codified in Terraform with policy enforcement via OPA.

## Why a Custom Landing Zone (Not Control Tower)

This implementation intentionally avoids AWS Control Tower in favor of a fully Terraform-managed approach. See [ADR-001](./docs/decisions/001-custom-vs-control-tower.md) for the detailed reasoning.

## Architecture

![Architecture Diagram](./docs/diagrams/architecture.png)

### Organizational Structure

\`\`\`
Root
├── Security OU
│   ├── Log Archive Account     (centralized CloudTrail logs)
│   └── Security Account        (GuardDuty, Security Hub aggregator)
├── Infrastructure OU
│   ├── Network Account         (Transit Gateway, shared VPCs)
│   └── Shared Services Account (DNS, ACM, ECR cache)
└── Workloads OU
    ├── Non-Prod OU
    │   ├── Dev Account
    │   └── Staging Account
    └── Prod OU
        └── Production Account
\`\`\`

## Project Structure

\`\`\`
.
├── terraform/
│   ├── 00-bootstrap/        # S3 backend + DynamoDB lock
│   ├── 01-organization/     # AWS Organization, OUs, SCPs
│   ├── 02-security-account/ # GuardDuty, Security Hub
│   ├── 03-logging-account/  # Centralized CloudTrail, S3 log buckets
│   ├── 04-network-account/  # Transit Gateway, shared VPCs
│   ├── 05-identity-center/  # SSO, permission sets, groups
│   ├── 06-account-vending/  # Automated account creation
│   └── 07-shared-services/  # DNS, ACM, common resources
├── policies/                 # OPA/Rego policies for Terraform
├── scripts/                  # Helper scripts (cost monitoring, etc.)
├── docs/
│   ├── decisions/            # Architecture Decision Records (ADRs)
│   ├── diagrams/             # Architecture diagrams
│   ├── ARCHITECTURE.md
│   ├── COST-ANALYSIS.md
│   └── RUNBOOK.md
└── .github/workflows/        # CI/CD pipelines
\`\`\`

## Getting Started

### Prerequisites

- AWS account with admin permissions
- Terraform 1.9+
- AWS CLI v2
- GitHub account (for OIDC authentication)

### Quick Start

1. Bootstrap the Terraform backend:
   \`\`\`bash
   cd terraform/00-bootstrap
   terraform init
   terraform apply
   \`\`\`

2. Deploy the AWS Organization and OUs:
   \`\`\`bash
   cd ../01-organization
   terraform init
   terraform apply
   \`\`\`

3. Follow the deployment order in [DEPLOYMENT.md](./docs/DEPLOYMENT.md)

## Documentation

- [Architecture](./docs/ARCHITECTURE.md)
- [Architecture Decision Records](./docs/decisions/)
- [Cost Analysis](./docs/COST-ANALYSIS.md)
- [Operational Runbook](./docs/RUNBOOK.md)

## Status

🚧 **Work in progress** — This is a learning portfolio project documenting the implementation journey.

## License

MIT — see [LICENSE](./LICENSE) for details.