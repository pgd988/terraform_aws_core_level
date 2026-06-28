variable "aws_region" {
  description = "The AWS region to deploy the infrastructure to"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "The CIDR block for the core VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "A list of CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "A list of CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "A list of availability zones to use"
  type        = list(string)
  default     = ["eu-central-1a", "eu-central-1b"]
}

variable "enable_route53" {
  description = "Whether to provision the private Route53 hosted zone"
  type        = bool
  default     = false
}

variable "enable_vpc_flow_logs" {
  description = "When true, enables VPC Flow Logs to CloudWatch for network traffic visibility (fixes Trivy AWS-0178). Incurs CloudWatch ingestion costs."
  type        = bool
  default     = false
}

variable "vpc_flow_logs_retention_days" {
  description = "Number of days to retain VPC Flow Log records in CloudWatch. Lower values reduce cost."
  type        = number
  default     = 14
}
