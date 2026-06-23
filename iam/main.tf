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
