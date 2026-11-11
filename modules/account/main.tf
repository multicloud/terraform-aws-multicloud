# Creates a new AWS account in your AWS Organizations.
#
# This module runs with YOUR management account credentials. Multicloud never gets them,
# and Multicloud gets no permission in the management account.
# AWS creates the role OrganizationAccountAccessRole in the new account. It trusts the
# management account. Your Terraform uses it to work inside the new account.

data "aws_partition" "current" {}

resource "aws_organizations_account" "this" {
  name      = var.name
  email     = var.email
  parent_id = var.parent_id

  role_name = "OrganizationAccountAccessRole"

  # terraform destroy closes the account. AWS keeps a closed account for 90 days.
  close_on_deletion = true

  lifecycle {
    # AWS ignores role_name after the account exists. Without this, a change would plan a replacement.
    ignore_changes = [role_name]
  }
}
