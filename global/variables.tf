variable "enable_aws_organization" {
  description = <<-EOT
    When true, creates an AWS Organization and attaches all SCPs.
    Set to false for free-tier AWS accounts — creating an Organisation will
    remove the account's free-tier credits.
  EOT
  type        = bool
  default     = false
}

variable "aws_region" {
  description = "The AWS region to deploy the infrastructure to"
  type        = string
  default     = "eu-central-1"
}

variable "enable_scp_deny_cloudtrail_changes" {
  description = "When true, attaches an SCP to the Organisation root that denies all CloudTrail create/mutate/delete actions across every member account."
  type        = bool
  default     = false
}
