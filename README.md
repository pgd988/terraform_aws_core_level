# AWS Core Level Infrastructure

This repository contains the foundational Terraform configurations for the AWS Core Level Infrastructure. To maintain a clean architecture, reduce blast radius, and decouple state files, the infrastructure is split into three independent Terraform root modules.

## Architecture

### 1. Bootstrap (`/bootstrap`)
Manages the infrastructure required to store Terraform states remotely.
- **S3 Bucket:** Provisions a versioned and encrypted S3 bucket for storing `.tfstate` files.
- **DynamoDB Table:** Provisions a DynamoDB table used for state locking to prevent concurrent operations from corrupting the state.

### 2. Global (`/global`)
Manages organization-wide settings.
- **AWS Organization:** Provisions the root organization structure.
- **Service Control Policies (SCPs):** Includes a policy attached to the root that explicitly denies all access to Amazon Bedrock (`bedrock:*`).

### 3. IAM (`/iam`)
Manages identity and access.
- **IAM Identity Center:** Uses the existing Identity Center instance (which **must** be enabled manually in the AWS Console first) to create an `admin` Permission Set.
- **Policies:** Attaches the `AdministratorAccess` managed policy to the `admin` Permission Set.

### 4. Network (`/network`)
Manages all core networking infrastructure in `eu-central-1`.
- **VPC & Subnets:** Creates a core VPC (`10.0.0.0/16`) with Public and Private subnets spanning multiple Availability Zones.
- **Network ACLs:** A strictly locked-down NACL that only permits inbound TCP port 22 (SSH) and TCP port 53 (DNS). All outbound traffic is permitted.
- **Security Groups:** A `core-default-sg` security group allowing inbound SSH/DNS and outbound internet.
- **DNS:** Provisions a private Route53 Hosted Zone (`.local`) attached to the VPC.
- **State Sharing (SSM):** Exports critical IDs (VPC ID, Subnet IDs, Security Group ID) to the AWS Systems Manager (SSM) Parameter Store under `/infra/networking/`. This allows downstream environments (like EKS clusters) to easily dynamically query and import these network boundaries.

## Prerequisites

- Terraform `~> 1.5.0`
- AWS CLI configured with administrative access to the Management Account.
- **AWS IAM Identity Center must be enabled manually in the AWS Console before applying the `iam` state.**

## Usage

Because the states are decoupled, you execute Terraform in each directory independently.

> [!IMPORTANT]
> **First-Time Setup:** You must initialize and apply the `bootstrap` module *before* running `terraform plan` or `terraform apply` in any of the other directories. The other modules rely on the S3 bucket and DynamoDB table created by `bootstrap` for their remote state backends.

```bash
cd bootstrap
terraform init
terraform plan
terraform apply
```

Once the `bootstrap` infrastructure is in place, you can manage the `global`, `iam`, and `network` modules completely independently of each other. Just navigate to the respective directory and run your standard Terraform commands.
