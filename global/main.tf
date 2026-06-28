# ──────────────────────────────────────────────────────────────────────────────
# AWS Organization
# Toggle with: enable_aws_organization = true / false
#
# NOTE: Free-tier AWS accounts lose their free credits when an Organisation is
# created. Set enable_aws_organization = false to skip this and all dependent
# SCP resources.
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_organizations_organization" "org" {
  count = var.enable_aws_organization ? 1 : 0

  feature_set = "ALL"

  aws_service_access_principals = [
    "sso.amazonaws.com"
  ]
}

# ──────────────────────────────────────────────────────────────────────────────
# SCP – Deny Amazon Bedrock
# Requires: enable_aws_organization = true
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_organizations_policy" "disable_bedrock" {
  count = var.enable_aws_organization ? 1 : 0

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

resource "aws_organizations_policy_attachment" "root_disable_bedrock" {
  count = var.enable_aws_organization ? 1 : 0

  policy_id = aws_organizations_policy.disable_bedrock[0].id
  target_id = aws_organizations_organization.org[0].roots[0].id
}

# ──────────────────────────────────────────────────────────────────────────────
# SCP – Deny CloudTrail mutations
# Requires: enable_aws_organization = true
# Toggle independently with: enable_scp_deny_cloudtrail_changes = true / false
# ──────────────────────────────────────────────────────────────────────────────
resource "aws_organizations_policy" "deny_cloudtrail_changes" {
  # Both conditions must be true: org must exist AND the SCP toggle must be on
  count = var.enable_aws_organization && var.enable_scp_deny_cloudtrail_changes ? 1 : 0

  name        = "DenyCloudTrailChanges"
  description = "Prevents any principal from mutating or disabling CloudTrail trails"
  type        = "SERVICE_CONTROL_POLICY"

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "DenyChangesToCloudTrail"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:UpdateTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:StartLogging",
          "cloudtrail:PutEventSelectors",
          "cloudtrail:PutInsightSelectors",
          "cloudtrail:AddTags",
          "cloudtrail:RemoveTags",
        ]
        Resource = "*"
      },
      {
        Sid      = "DenyCreateTrail"
        Effect   = "Deny"
        Action   = "cloudtrail:CreateTrail"
        Resource = "*"
      },
    ]
  })
}

resource "aws_organizations_policy_attachment" "root_deny_cloudtrail_changes" {
  count = var.enable_aws_organization && var.enable_scp_deny_cloudtrail_changes ? 1 : 0

  policy_id = aws_organizations_policy.deny_cloudtrail_changes[0].id
  target_id = aws_organizations_organization.org[0].roots[0].id
}
