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
