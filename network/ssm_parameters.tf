resource "aws_ssm_parameter" "vpc_id" {
  name        = "/infra/networking/vpc_id"
  type        = "String"
  value       = aws_vpc.main.id
  description = "Managed by Terraform. VPC ID."
}

resource "aws_ssm_parameter" "public_subnets" {
  name        = "/infra/networking/public_subnets"
  type        = "StringList"
  value       = join(",", aws_subnet.public[*].id)
  description = "Managed by Terraform. Public Subnet IDs."
}

resource "aws_ssm_parameter" "private_subnets" {
  name        = "/infra/networking/private_subnets"
  type        = "StringList"
  value       = join(",", aws_subnet.private[*].id)
  description = "Managed by Terraform. Private Subnet IDs."
}

resource "aws_ssm_parameter" "default_security_group_id" {
  name        = "/infra/networking/default_security_group_id"
  type        = "String"
  value       = aws_security_group.default.id
  description = "Managed by Terraform. Default Security Group ID."
}

resource "aws_ssm_parameter" "private_route_tables" {
  name        = "/infra/networking/private_route_tables"
  type        = "StringList"
  value       = join(",", aws_route_table.private[*].id)
  description = "Managed by Terraform. Private Route Table IDs."
}

resource "aws_ssm_parameter" "nat_gateway_ids" {
  name        = "/infra/networking/nat_gateway_ids"
  type        = "StringList"
  value       = join(",", aws_nat_gateway.main[*].id)
  description = "Managed by Terraform. NAT Gateway IDs."
}
