resource "aws_route53_zone" "local" {
  name = "local"

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = {
    Name = "core-local-zone"
  }
}
