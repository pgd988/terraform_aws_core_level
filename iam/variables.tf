variable "aws_region" {
  description = "The AWS region to deploy the infrastructure to"
  type        = string
  default     = "eu-central-1"
}

variable "enable_identity_center" {
  description = "Whether to provision IAM Identity Center permission sets and assignments"
  type        = bool
  default     = false
}

variable "enable_github_actions_role" {
  description = "When true, creates an IAM OIDC provider for GitHub Actions and the GitHubActionsRole that CI workflows can assume via sts:AssumeRoleWithWebIdentity."
  type        = bool
  default     = true
}

variable "github_org" {
  description = "GitHub organisation (or user) name that owns the repository. Used to scope the OIDC trust policy, e.g. 'my-org'."
  type        = string
  default     = "pgd988"
}

variable "github_repo" {
  description = "GitHub repository name (without the org prefix). Used to scope the OIDC trust policy, e.g. 'terraform_aws_core_level'."
  type        = string
  default     = "terraform_gcp_core_level_infra"
}
