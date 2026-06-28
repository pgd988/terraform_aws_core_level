# AWS Core Level Infrastructure

This repository contains the foundational Terraform configurations for the AWS Core Level Infrastructure. To maintain a clean architecture, reduce blast radius, and decouple state files, the infrastructure is split into four independent Terraform root modules.

## Repository Structure

```
.
├── bootstrap/   # Remote state backend (S3 + DynamoDB) — apply first
├── global/      # AWS Organization & Service Control Policies
├── iam/         # IAM groups, Identity Center, GitHub Actions OIDC role
├── network/     # VPC, subnets, security groups, Route53, SSM exports
└── .github/
    └── workflows/
        └── ci.yml   # Trivy security scan → Terraform plan pipeline
```

---

## Architecture

### 1. Bootstrap (`/bootstrap`)
Manages the infrastructure required to store Terraform state remotely. **Must be applied first.**

| Resource | Purpose |
|---|---|
| S3 Bucket | Versioned, AES-256 encrypted bucket for `.tfstate` files. `prevent_destroy` lifecycle guard enabled. |
| DynamoDB Table | State locking table — prevents concurrent operations from corrupting state. |

**Key variables**

| Variable | Default | Description |
|---|---|---|
| `state_bucket_name` | `core-infra-terraform-state-bucket` | Globally unique S3 bucket name |
| `dynamodb_table_name` | `core-infra-terraform-state-locks` | DynamoDB table name |

---

### 2. Global (`/global`)
Manages organisation-wide settings. All resources are opt-in via feature toggles.

| Resource | Purpose |
|---|---|
| AWS Organization | Root organisation structure with `ALL` features + SSO service access |
| SCP – Deny Bedrock | Org-root SCP that denies all `bedrock:*` actions across member accounts |
| SCP – Deny CloudTrail changes | Org-root SCP that blocks create/mutate/delete CloudTrail actions (independent toggle) |

**Feature toggles**

| Variable | Default | Description |
|---|---|---|
| `enable_aws_organization` | `false` | Creates the org and all SCPs. **Set to `false` for free-tier accounts** — creating an Organisation strips free-tier credits. |
| `enable_scp_deny_cloudtrail_changes` | `false` | Attaches the CloudTrail mutation deny SCP. Requires `enable_aws_organization = true`. |

> [!IMPORTANT]
> **CloudTrail management workflow:** The CloudTrail SCP blocks **all** CloudTrail mutations across member accounts. To make changes, toggle it off → apply → make changes → toggle on → apply. The management account is always exempt from SCPs by AWS design.

---

### 3. IAM (`/iam`)
Manages identity and access management.

| Resource | Purpose |
|---|---|
| SSO Permission Set – `admin` | `AdministratorAccess` via IAM Identity Center |
| SSO Permission Set – `developers` | `CloudWatchReadOnlyAccess` via IAM Identity Center |
| IAM Group – `admin` | Fallback when Identity Center is disabled |
| IAM Group – `developers` | Fallback when Identity Center is disabled |
| OIDC Provider | Registers `token.actions.githubusercontent.com` with your AWS account |
| IAM Role – `GitHubActionsRole` | Assumed by GitHub Actions via OIDC (no long-lived credentials) |

**Feature toggles**

| Variable | Default | Description |
|---|---|---|
| `enable_identity_center` | `false` | Provisions SSO permission sets. IAM Identity Center must be enabled manually in the AWS Console first. |
| `enable_github_actions_role` | `false` | Creates the OIDC provider and `GitHubActionsRole` for CI/CD. |
| `github_org` | `""` | GitHub organisation or username (used to scope the role trust policy). |
| `github_repo` | `""` | GitHub repository name without the org prefix. |

**GitHub Actions role policy grants**
- S3: read/write to the Terraform state bucket
- DynamoDB: get/put/delete on the state lock table
- Read-only describe access for: EC2, IAM, Organizations, Route53, SSM

---

### 4. Network (`/network`)
Manages all core networking infrastructure in `eu-central-1`.

| Resource | Purpose |
|---|---|
| VPC | `10.0.0.0/16` core VPC |
| Public & Private Subnets | Spanning multiple Availability Zones |
| Network ACLs | Inbound: TCP 22 (SSH) + TCP 53 (DNS) only. Outbound: all permitted. |
| Security Group – `core-default-sg` | Inbound SSH/DNS, outbound internet |
| Route53 Private Zone | `.local` hosted zone attached to the VPC |
| SSM Parameters | Exports VPC ID, Subnet IDs, and SG ID to `/infra/networking/*` for downstream consumption |

---

## CI/CD Pipeline (`.github/workflows/ci.yml`)

The pipeline runs on every push and pull request to `main`.

```
[push / PR to main]
       │
       ▼
┌──────────────────────┐
│  Job 1: Trivy Scan   │  Scans all IaC config files for misconfigurations
│  (config scan)       │  ✗ CRITICAL findings → pipeline fails here
│                      │  ✓ SARIF report uploaded to GitHub Security tab
└──────────┬───────────┘
           │ no CRITs found
           ▼
┌──────────────────────────────────────────────────────┐
│  Job 2: Terraform Plan  (matrix: all 4 modules)      │
│  bootstrap │ global │ iam │ network  (parallel)      │
│                                                      │
│  Steps per module:                                   │
│    1. AWS auth via OIDC (GitHubActionsRole)          │
│    2. terraform init                                 │
│    3. terraform validate                             │
│    4. terraform plan  →  posts output to PR comment  │
│    5. Upload plan binary as artifact (7 days)        │
└──────────────────────────────────────────────────────┘
```

**Required configuration**

| Item | Where |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Set in `env:` block in `ci.yml` — the ARN of `GitHubActionsRole` created by the `iam` module |
| AWS OIDC provider | Created by `aws_iam_openid_connect_provider.github_actions` in the `iam` module |
| `GITHUB_TOKEN` | Automatic — provided by GitHub, no setup needed |

---

## Prerequisites

- Terraform `>= 1.5.0`
- AWS CLI configured with administrative access to the management account
- **IAM Identity Center** must be enabled manually in the AWS Console before applying with `enable_identity_center = true`

---

## Usage

> [!IMPORTANT]
> **First-time setup:** Apply `bootstrap` before any other module. All other modules depend on the S3 bucket and DynamoDB table it creates.

### Step 1 — Bootstrap (remote state backend)

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

### Step 2 — Remaining modules (independent, any order)

```bash
cd global   # or iam / network
terraform init
terraform plan
terraform apply
```

### Enabling the GitHub Actions OIDC role

```hcl
# iam/terraform.tfvars
enable_github_actions_role = true
github_org                 = "your-github-org"
github_repo                = "terraform_aws_core_level"
```

Apply the `iam` module, copy the created role ARN, then set `AWS_DEPLOY_ROLE_ARN` in `.github/workflows/ci.yml`.

### Enabling the AWS Organization (paid accounts only)

```hcl
# global/terraform.tfvars
enable_aws_organization             = true
enable_scp_deny_cloudtrail_changes  = true   # optional
```

> [!WARNING]
> Setting `enable_aws_organization = true` on a free-tier AWS account will remove its free-tier credits. Leave as `false` if you are on a free plan.
