# AWS Organizations setup
resource "aws_organizations_organization" "org" {
  feature_set = "ALL"

  aws_service_access_principals = [
    "sso.amazonaws.com"
  ]
}

# SCP to explicitly disable Amazon Bedrock
resource "aws_organizations_policy" "disable_bedrock" {
  name        = "DisableAmazonBedrock"
  description = "Disables access to Amazon Bedrock explicitly"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyBedrock"
        Effect   = "Deny"
        Action   = "bedrock:*"
        Resource = "*"
      }
    ]
  })
}

# Attach SCP to the Organization root
resource "aws_organizations_policy_attachment" "root_disable_bedrock" {
  policy_id = aws_organizations_policy.disable_bedrock.id
  target_id = aws_organizations_organization.org.roots[0].id
}
