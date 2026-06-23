# Fetch the IAM Identity Center (formerly AWS SSO) instance
# Note: You must enable IAM Identity Center in the AWS Console first.
data "aws_ssoadmin_instances" "this" {}

# Create "admin" permission set
resource "aws_ssoadmin_permission_set" "admin" {
  name             = "admin"
  description      = "Administrator Access for managing the account"
  instance_arn     = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  session_duration = "PT8H" # 8 hours session duration
}

# Attach AdministratorAccess managed policy to the permission set
resource "aws_ssoadmin_managed_policy_attachment" "admin_access" {
  instance_arn       = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
  permission_set_arn = aws_ssoadmin_permission_set.admin.arn
}
