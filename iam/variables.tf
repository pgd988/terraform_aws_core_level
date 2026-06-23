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
