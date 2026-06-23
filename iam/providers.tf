terraform {
  backend "s3" {
    bucket         = "core-infra-terraform-state-bucket"
    key            = "iam/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "core-infra-terraform-state-locks"
    encrypt        = true
  }
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = "core"
      ManagedBy   = "terraform"
    }
  }
}
