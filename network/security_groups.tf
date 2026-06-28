resource "aws_security_group" "default" {
  name        = "core-default-sg"
  description = "Default security group allowing SSH and DNS inbound, explicit minimal egress"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "core-default-sg"
  }
}

# ── Ingress ───────────────────────────────────────────────────────────────────

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  security_group_id = aws_security_group.default.id
  description       = "SSH inbound"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "dns_tcp" {
  security_group_id = aws_security_group.default.id
  description       = "DNS TCP inbound"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "dns_udp" {
  security_group_id = aws_security_group.default.id
  description       = "DNS UDP inbound"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"
}

# ── Egress – explicit minimal set (fixes Trivy AWS-0104) ─────────────────────
# Security groups are stateful – return traffic is handled automatically,
# so no ephemeral-port rules are needed here (unlike NACLs).

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.default.id
  description       = "HTTPS outbound – AWS APIs, package repos"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "http" {
  security_group_id = aws_security_group.default.id
  description       = "HTTP outbound – package mirrors, redirects"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "dns_tcp" {
  security_group_id = aws_security_group.default.id
  description       = "DNS TCP outbound"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "dns_udp" {
  security_group_id = aws_security_group.default.id
  description       = "DNS UDP outbound"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  cidr_ipv4         = "0.0.0.0/0"
}
