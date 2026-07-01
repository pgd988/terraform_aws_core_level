resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "core-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "core-public-${var.availability_zones[count.index]}"
    Tier = "Public"
  }
}

# Private Subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "core-private-${var.availability_zones[count.index]}"
    Tier = "Private"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "core-igw"
  }
}

# Public Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "core-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Private Route Table
resource "aws_route_table" "private" {
  count  = var.single_nat_gateway || !var.enable_nat_gateway ? 1 : length(var.availability_zones)
  vpc_id = aws_vpc.main.id

  tags = {
    Name = var.single_nat_gateway || !var.enable_nat_gateway ? "core-private-rt" : "core-private-rt-${var.availability_zones[count.index]}"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = var.single_nat_gateway || !var.enable_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
}

# Elastic IP for NAT Gateway
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  domain = "vpc"

  tags = {
    Name = var.single_nat_gateway ? "core-nat-eip-${var.availability_zones[0]}" : "core-nat-eip-${var.availability_zones[count.index]}"
  }

  depends_on = [aws_internet_gateway.main]
}

# NAT Gateway (Provisions in public subnet eu-central-1a by default when single_nat_gateway = true)
resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = var.single_nat_gateway ? "core-nat-gw-${var.availability_zones[0]}" : "core-nat-gw-${var.availability_zones[count.index]}"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route for outbound internet access via NAT Gateway (enables private subnet nodes to reach EKS API)
resource "aws_route" "private_nat_gateway" {
  count                  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.availability_zones)) : 0
  route_table_id         = var.single_nat_gateway ? aws_route_table.private[0].id : aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[count.index].id
}

# Network ACL
resource "aws_network_acl" "main" {
  vpc_id = aws_vpc.main.id

  subnet_ids = concat(aws_subnet.public[*].id, aws_subnet.private[*].id)

  tags = {
    Name = "core-nacl"
  }
}

# NACL Egress Rules – explicit minimal set (replaces unrestricted all-protocol rule)

# HTTPS outbound (AWS APIs, package repos, etc.)
resource "aws_network_acl_rule" "egress_https" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 100
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# HTTP outbound (package repos / redirects)
resource "aws_network_acl_rule" "egress_http" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 110
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# DNS outbound – TCP
resource "aws_network_acl_rule" "egress_dns_tcp" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 120
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
}

# DNS outbound – UDP
resource "aws_network_acl_rule" "egress_dns_udp" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 130
  egress         = true
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
}

# Ephemeral ports outbound – required for stateless NACL return traffic
# (covers TCP return packets for inbound SSH / DNS connections)
resource "aws_network_acl_rule" "egress_ephemeral" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 140
  egress         = true
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# Ephemeral UDP ports outbound – required for UDP return traffic and CNI overlay networking
resource "aws_network_acl_rule" "egress_ephemeral_udp" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 150
  egress         = true
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# NTP outbound (UDP 123) for node clock synchronization
resource "aws_network_acl_rule" "egress_ntp" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 160
  egress         = true
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 123
  to_port        = 123
}

# NACL Ingress Rules

resource "aws_network_acl_rule" "ingress_ssh" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 100
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 22
  to_port        = 22
}

resource "aws_network_acl_rule" "ingress_dns_tcp" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 110
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
}

# DNS ingress – UDP
resource "aws_network_acl_rule" "ingress_dns_udp" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 120
  egress         = false
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 53
  to_port        = 53
}

# Ephemeral ports ingress – required for return traffic from internet/AWS APIs via NAT Gateway
resource "aws_network_acl_rule" "ingress_ephemeral" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 130
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# HTTPS ingress – required for traffic arriving at NAT Gateway from private subnets
resource "aws_network_acl_rule" "ingress_https" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 140
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 443
  to_port        = 443
}

# HTTP ingress – required for package repositories and HTTP redirects via NAT Gateway
resource "aws_network_acl_rule" "ingress_http" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 150
  egress         = false
  protocol       = "tcp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 80
  to_port        = 80
}

# Ephemeral UDP ports ingress – required for UDP return traffic and CNI overlay networking
resource "aws_network_acl_rule" "ingress_ephemeral_udp" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 160
  egress         = false
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 1024
  to_port        = 65535
}

# NTP ingress (UDP 123) for node clock synchronization return packets
resource "aws_network_acl_rule" "ingress_ntp" {
  network_acl_id = aws_network_acl.main.id
  rule_number    = 170
  egress         = false
  protocol       = "udp"
  rule_action    = "allow"
  cidr_block     = "0.0.0.0/0"
  from_port      = 123
  to_port        = 123
}

# ──────────────────────────────────────────────────────────────────────────────
# VPC Flow Logs  (fixes Trivy AWS-0178)
# Toggle with: enable_vpc_flow_logs = true / false
# ──────────────────────────────────────────────────────────────────────────────

# CloudWatch Log Group to receive flow log records
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name              = "/aws/vpc/flow-logs/${aws_vpc.main.id}"
  retention_in_days = var.vpc_flow_logs_retention_days

  tags = {
    Name = "core-vpc-flow-logs"
  }
}

# IAM role that grants the VPC Flow Logs service permission to write to CloudWatch
resource "aws_iam_role" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name        = "VpcFlowLogsRole"
  description = "Allows VPC Flow Logs to publish to CloudWatch Logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  name = "VpcFlowLogsPolicy"
  role = aws_iam_role.vpc_flow_logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ]
        Resource = "*"
      }
    ]
  })
}

# VPC Flow Log – captures ALL traffic (ACCEPT + REJECT) for security visibility
resource "aws_flow_log" "main" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  vpc_id          = aws_vpc.main.id
  traffic_type    = "ALL"
  iam_role_arn    = aws_iam_role.vpc_flow_logs[0].arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs[0].arn

  tags = {
    Name = "core-vpc-flow-log"
  }
}
