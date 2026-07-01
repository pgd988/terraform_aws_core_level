variable "aws_region" {
  description = "The AWS region to deploy the infrastructure to"
  type        = string
  default     = "eu-central-1"
}

variable "state_bucket_name" {
  description = "Name of the S3 bucket for Terraform state (must be globally unique)"
  type        = string
  default     = "core-infra-terraform-state-bucket"
}

variable "dynamodb_table_name" {
  description = "Name of the DynamoDB table for Terraform state locking"
  type        = string
  default     = "core-infra-terraform-state-locks"
}

variable "github_org" {
  description = "GitHub organisation (or user) name that owns the repository. Used to scope the OIDC trust policy, e.g. 'my-org'."
  type        = string
  default     = "pgd988"
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix). Used to scope the OIDC trust policy, e.g. 'terraform_aws_core_level'."
  type        = string
  default     = "terraform_aws_core_level"
}

variable "github_platform_repo" {
  description = "GitHub repository name for the platform-level repo (without the org prefix). Used to scope the OIDC trust policy, e.g. 'terraform_aws_platform_level'."
  type        = string
  default     = "terraform_aws_platform_level"
}
