resource "aws_security_group" "default" {
  name        = "core-default-sg"
  description = "Default security group allowing SSH and DNS inbound, and unrestricted outbound"
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

# ── Egress ────────────────────────────────────────────────────────────────────
# Unrestricted outbound is intentional for this core default SG.
# Trivy AWS-0104 is suppressed via .trivyignore at the repo root.

resource "aws_vpc_security_group_egress_rule" "all_outbound" {
  security_group_id = aws_security_group.default.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
