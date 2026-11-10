# Service-linked roles that EC2 Spot and EC2 Fleet need (R7), and the one that Service Quotas
# needs before it accepts the first quota increase request of an account (without it,
# RequestServiceQuotaIncrease fails with DependencyAccessDeniedException). The provisioner role
# cannot create them, and a second create call fails with "already exists". So the module looks
# for each role first and creates it only when the account has none.
#
# Each role is decided on its own, from what the account has:
#
# - The account has no such role: the module creates it.
# - The role carries the marker of THIS module instance (the description names this
#   connection, account_row_id): the module created it, so it keeps it (count stays 1).
# - Any other description (AWS, the console, another tool, or another instance of this module
#   for another connection): the role exists, so EC2 and Service Quotas can use it. The module
#   leaves it alone and plans nothing for it.
#
# Why the description marker exists: the lookup (data.aws_iam_roles) runs on every plan, and
# after the first apply it finds the role that this module created. Without a marker, the
# second plan would see "the account already has the role", set count to 0 and destroy the
# role that the module itself created (a regions-only change or a token re-issue would do it).
# The marker names the connection, so a second instance of the module in the same account sees
# the roles of the first one as foreign and never tries to create them again.
#
# The count uses only data sources and input variables, so the plan knows it (random_id.suffix
# is unknown on the first plan and cannot be in the marker).
#
# Modules 1.1.0 and older used one fixed marker for every instance (local.slr_legacy_marker).
# The module still treats a role with that marker as its own, so an upgrade keeps the roles
# that the state holds; the apply then changes the description to the new marker in place.
# Limit: a role with one of these two markers that THIS state does not hold still plans a
# create, and AWS answers "already exists". That happens after a loss of the Terraform state,
# or when another folder created the role with module 1.1.0 or older. Fix: apply the new
# module version in the folder that created the role (that rewrites its marker), or change
# the role description in IAM to any other text. The next plan then leaves the role alone.
# On destroy, Terraform deletes only the roles that this state holds.

locals {
  slr_marker        = "Created by the Multicloud connect module (connection ${var.account_row_id})"
  slr_legacy_marker = "Created by the Multicloud connect module"
  slr_own_markers   = [local.slr_marker, local.slr_legacy_marker]

  slr_create = {
    spot          = length(data.aws_iam_roles.spot.names) == 0 || contains(local.slr_own_markers, try(data.aws_iam_role.spot[0].description, ""))
    fleet         = length(data.aws_iam_roles.fleet.names) == 0 || contains(local.slr_own_markers, try(data.aws_iam_role.fleet[0].description, ""))
    servicequotas = length(data.aws_iam_roles.servicequotas.names) == 0 || contains(local.slr_own_markers, try(data.aws_iam_role.servicequotas[0].description, ""))
  }
}

data "aws_iam_roles" "spot" {
  path_prefix = "/aws-service-role/spot.amazonaws.com/"
}

data "aws_iam_roles" "fleet" {
  path_prefix = "/aws-service-role/ec2fleet.amazonaws.com/"
}

data "aws_iam_roles" "servicequotas" {
  path_prefix = "/aws-service-role/servicequotas.amazonaws.com/"
}

data "aws_iam_role" "spot" {
  count = length(data.aws_iam_roles.spot.names) == 0 ? 0 : 1
  name  = tolist(data.aws_iam_roles.spot.names)[0]
}

data "aws_iam_role" "fleet" {
  count = length(data.aws_iam_roles.fleet.names) == 0 ? 0 : 1
  name  = tolist(data.aws_iam_roles.fleet.names)[0]
}

data "aws_iam_role" "servicequotas" {
  count = length(data.aws_iam_roles.servicequotas.names) == 0 ? 0 : 1
  name  = tolist(data.aws_iam_roles.servicequotas.names)[0]
}

resource "aws_iam_service_linked_role" "spot" {
  count            = var.manage_service_linked_roles && local.slr_create.spot ? 1 : 0
  aws_service_name = "spot.amazonaws.com"
  description      = local.slr_marker
}

resource "aws_iam_service_linked_role" "fleet" {
  count            = var.manage_service_linked_roles && local.slr_create.fleet ? 1 : 0
  aws_service_name = "ec2fleet.amazonaws.com"
  description      = local.slr_marker
}

resource "aws_iam_service_linked_role" "servicequotas" {
  count            = var.manage_service_linked_roles && local.slr_create.servicequotas ? 1 : 0
  aws_service_name = "servicequotas.amazonaws.com"
  description      = local.slr_marker
}
