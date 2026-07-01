resource "aws_s3_bucket" "terraform_state" {
  bucket = var.state_bucket_name

  # Prevent accidental deletion of this S3 bucket
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name         = var.dynamodb_table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ──────────────────────────────────────────────────────────────────────────────
# GitHub Actions – OIDC integration
# Bootstrapped manually so it exists before CI first runs.
# Creates an IAM OIDC identity provider and the GitHubActionsRole that
# GitHub Actions assumes via sts:AssumeRoleWithWebIdentity (no static keys).
# ──────────────────────────────────────────────────────────────────────────────

# GitHub's OIDC provider (one per account – safe to apply even if it already exists)
resource "aws_iam_openid_connect_provider" "github_actions" {
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
  name        = "GitHubActionsRole"
  description = "Assumed by GitHub Actions via OIDC - no long-lived credentials"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
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

# Permissions for GitHub Actions CI: state bucket + lock table +
# read-only access for plan, write access for apply across all managed services.
resource "aws_iam_role_policy" "github_actions_terraform" {
  name = "TerraformCIAccess"
  role = aws_iam_role.github_actions.id

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
          "arn:aws:s3:::${var.state_bucket_name}",
          "arn:aws:s3:::${var.state_bucket_name}/*",
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
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/${var.dynamodb_table_name}"
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
          "s3:Get*",
          "s3:List*",
          "ssm:GetParameter*",
          "ssm:DescribeParameters",
          "ssm:ListTagsForResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "StateLockReadOnly"
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:ListTagsOfResource",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:DescribeContinuousBackups",
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/${var.dynamodb_table_name}"
      },
      {
        Sid    = "ApplyPermissions"
        Effect = "Allow"
        Action = [
          "ec2:*",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:AddTagsToResource",
          "ssm:RemoveTagsFromResource",
          "route53:ChangeResourceRecordSets",
          "route53:CreateHostedZone",
          "route53:DeleteHostedZone",
          "logs:CreateLogGroup",
          "logs:DeleteLogGroup",
          "logs:PutRetentionPolicy",
          "logs:TagLogGroup",
          "logs:ListTagsLogGroup",
          "logs:ListTagsForResource",
        ]
        Resource = "*"
      },
    ]
  })
}

# ──────────────────────────────────────────────────────────────────────────────
# GitHub Actions – IAM role for terraform_aws_platform_level
# Same policy as the core-level role; scoped to the platform-level repository.
# ──────────────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "github_actions_platform_level" {
  name        = "GitHubActionsRole-platform-level"
  description = "Assumed by GitHub Actions (pgd988/terraform_aws_platform_level) via OIDC"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github_actions.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_platform_repo}:*"
          }
        }
      }
    ]
  })

  tags = {
    ManagedBy = "terraform"
  }
}

resource "aws_iam_role_policy" "github_actions_terraform_platform_level" {
  name = "TerraformCIAccess"
  role = aws_iam_role.github_actions_platform_level.id

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
          "arn:aws:s3:::${var.state_bucket_name}",
          "arn:aws:s3:::${var.state_bucket_name}/*",
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
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/${var.dynamodb_table_name}"
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
          "s3:Get*",
          "s3:List*",
          "ssm:GetParameter*",
          "ssm:DescribeParameters",
          "ssm:ListTagsForResource",
        ]
        Resource = "*"
      },
      {
        Sid    = "StateLockReadOnly"
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:ListTagsOfResource",
          "dynamodb:DescribeTimeToLive",
          "dynamodb:DescribeContinuousBackups",
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:*:table/${var.dynamodb_table_name}"
      },
      {
        Sid    = "ApplyPermissions"
        Effect = "Allow"
        Action = [
          "cloudwatch:*",
          "cloudtrail:*",
          "xray:*",
          "elasticache:*",
          "rds:*",
          "ec2:*",
          "logs:*",
          "elasticloadbalancing:*",
          "acm:*",
          "kms:*",
          "ssm:PutParameter",
          "ssm:DeleteParameter",
          "ssm:AddTagsToResource",
          "ssm:RemoveTagsFromResource",
          "route53:ChangeResourceRecordSets",
          "route53:CreateHostedZone",
          "route53:DeleteHostedZone",
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMFullAccess"
        Effect = "Allow"
        Action = [
          "iam:*",
        ]
        Resource = "*"
      },
    ]
  })
}
