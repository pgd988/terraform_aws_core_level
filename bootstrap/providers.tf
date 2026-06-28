terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # ─── BOOTSTRAP STATE MIGRATION ──────────────────────────────────────────────
  #
  # Phase 1 – First-time apply (local state)
  #   Leave the backend block below COMMENTED OUT.
  #   Run: terraform init && terraform apply
  #   This creates the S3 bucket, DynamoDB table, and GitHubActionsRole in AWS.
  #
  # Phase 2 – Migrate state to S3
  #   Uncomment the backend block below, then run:
  #     terraform init -migrate-state
  #   Terraform will copy terraform.tfstate → S3 and delete the local file.
  #   From this point on, state is stored remotely and the bucket is the
  #   single source of truth for all modules.
  #
  # ──────────────────────────────────────────────────────────ß───────────────────

   backend "s3" {
     bucket         = "core-infra-terraform-state-bucket"
     key            = "bootstrap/terraform.tfstate"
     region         = "eu-central-1"
     dynamodb_table = "core-infra-terraform-state-locks"
     encrypt        = true
   }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "bootstrap"
      ManagedBy   = "terraform"
    }
  }
}
