resource "aws_route53_zone" "local" {
  count = var.enable_route53 ? 1 : 0
  name  = "local"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Name = "core-local-zone"
  }
}
