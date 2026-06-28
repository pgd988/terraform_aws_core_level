# Fetch the IAM Identity Center (formerly AWS SSO) instance
# Note: You must enable IAM Identity Center in the AWS Console first.
data "aws_ssoadmin_instances" "this" {
  count = var.enable_identity_center ? 1 : 0
}

# Create "admin" permission set
resource "aws_ssoadmin_permission_set" "admin" {
  count            = var.enable_identity_center ? 1 : 0
  name             = "admin"
  description      = "Administrator Access for managing the account"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this[0].arns)[0]
  session_duration = "PT8H" # 8 hours session duration
}

# Attach AdministratorAccess managed policy to the permission set
resource "aws_ssoadmin_managed_policy_attachment" "admin_access" {
  count              = var.enable_identity_center ? 1 : 0
  instance_arn       = tolist(data.aws_ssoadmin_instances.this[0].arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin[0].arn
}

# Create "developers" permission set
resource "aws_ssoadmin_permission_set" "developers" {
  count            = var.enable_identity_center ? 1 : 0
  name             = "developers"
  description      = "Read-only access to CloudWatch for developers"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this[0].arns)[0]
  session_duration = "PT8H"
}

# Attach CloudWatchReadOnlyAccess managed policy to the developers permission set
resource "aws_ssoadmin_managed_policy_attachment" "developers_cloudwatch" {
  count              = var.enable_identity_center ? 1 : 0
  instance_arn       = tolist(data.aws_ssoadmin_instances.this[0].arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
  permission_set_arn = aws_ssoadmin_permission_set.developers[0].arn
}

# --- Standard IAM Fallback (when Identity Center is disabled) ---

# Create "admin" IAM Group
resource "aws_iam_group" "admin" {
  count = var.enable_identity_center ? 0 : 1
  name  = "admin"
}

# Attach AdministratorAccess to admin IAM Group
resource "aws_iam_group_policy_attachment" "admin_access" {
  count      = var.enable_identity_center ? 0 : 1
  group      = aws_iam_group.admin[0].name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Create "developers" IAM Group
resource "aws_iam_group" "developers" {
  count = var.enable_identity_center ? 0 : 1
  name  = "developers"
}

# Attach CloudWatchReadOnlyAccess to developers IAM Group
resource "aws_iam_group_policy_attachment" "developers_cloudwatch" {
  count      = var.enable_identity_center ? 0 : 1
  group      = aws_iam_group.developers[0].name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchReadOnlyAccess"
}

# ──────────────────────────────────────────────────────────────────────────────
# GitHub Actions – OIDC integration
# Creates an IAM OIDC identity provider and a role that GitHub Actions can
# assume via sts:AssumeRoleWithWebIdentity (no long-lived keys required).
#
# Toggle with: enable_github_actions_role = true / false
# Required vars: github_org, github_repo
# ──────────────────────────────────────────────────────────────────────────────

# GitHub's OIDC provider (one per account – safe to run even if it already exists)
resource "aws_iam_openid_connect_provider" "github_actions" {
  count = var.enable_github_actions_role ? 1 : 0

  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  # Thumbprint list for token.actions.githubusercontent.com (GitHub-published value)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

# IAM role that GitHub Actions workflows can assume
resource "aws_iam_role" "github_actions" {
  count = var.enable_github_actions_role ? 1 : 0

  name        = "GitHubActionsRole"
  description = "Assumed by GitHub Actions via OIDC - no long-lived credentials"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions[0].arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # Scope to a specific repo; :* allows all branches/tags/PRs
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    ManagedBy = "terraform"
  }
}

# Minimal permissions for Terraform plan: read state from S3 + lock table,
# plus read-only access to the services being planned.
resource "aws_iam_role_policy" "github_actions_terraform_plan" {
  count = var.enable_github_actions_role ? 1 : 0

  name = "TerraformPlanAccess"
  role = aws_iam_role.github_actions[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "TerraformStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::core-infra-terraform-state-bucket",
          "arn:aws:s3:::core-infra-terraform-state-bucket/*",
        ]
      },
      {
        Sid    = "TerraformStateLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ]
        Resource = "arn:aws:dynamodb:eu-central-1:*:table/core-infra-terraform-state-locks"
      },
      {
        Sid    = "ReadOnlyForPlan"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "iam:Get*",
          "iam:List*",
          "organizations:Describe*",
          "organizations:List*",
          "route53:Get*",
          "route53:List*",
          "ssm:GetParameter*",
          "ssm:DescribeParameters",
          "ssm:ListTagsForResource",
        ]
        Resource = "*"
      },
    ]
  })
}
