# Service-linked roles that EC2 Spot and EC2 Fleet need (R7). The provisioner role cannot
# create them, and a second create call fails with "already exists". So the module looks for
# each role first and creates it only when the account has none.
#
# Why the description marker exists: the lookup (data.aws_iam_roles) runs on every plan, and
# after the first apply it finds the role that this module created. Without a marker, the
# second plan would see "the account already has the role", set count to 0 and destroy the
# role that the module itself created (a regions-only change or a token re-issue would do it).
# So the module gives the roles it creates a fixed description. It keeps count = 1 when the
# existing role carries that description, and uses count = 0 only for a role that someone
# else created. On destroy, Terraform deletes only the roles that carry the marker.

#
# Limit: a role with the marker but no entry in this module's state plans a create, and AWS
# rejects it with "already exists". That happens after a loss of the Terraform state, or for a
# second instance of this module in the same account. Keep the state. In those two cases set
# manage_service_linked_roles = false: the module then plans no service-linked role.

locals {
  slr_marker = "Created by the Multicloud connect module"
}

data "aws_iam_roles" "spot" {
  path_prefix = "/aws-service-role/spot.amazonaws.com/"
}

data "aws_iam_roles" "fleet" {
  path_prefix = "/aws-service-role/ec2fleet.amazonaws.com/"
}

data "aws_iam_role" "spot" {
  count = length(data.aws_iam_roles.spot.names) == 0 ? 0 : 1
  name  = tolist(data.aws_iam_roles.spot.names)[0]
}

data "aws_iam_role" "fleet" {
  count = length(data.aws_iam_roles.fleet.names) == 0 ? 0 : 1
  name  = tolist(data.aws_iam_roles.fleet.names)[0]
}

resource "aws_iam_service_linked_role" "spot" {
  count            = var.manage_service_linked_roles && (length(data.aws_iam_roles.spot.names) == 0 || try(data.aws_iam_role.spot[0].description, "") == local.slr_marker) ? 1 : 0
  aws_service_name = "spot.amazonaws.com"
  description      = local.slr_marker
}

resource "aws_iam_service_linked_role" "fleet" {
  count            = var.manage_service_linked_roles && (length(data.aws_iam_roles.fleet.names) == 0 || try(data.aws_iam_role.fleet[0].description, "") == local.slr_marker) ? 1 : 0
  aws_service_name = "ec2fleet.amazonaws.com"
  description      = local.slr_marker
}
