# The module creates the service-linked roles (SLRs) in a fresh account. On the next run the
# lookup finds the role that the module created. The module must keep it, not destroy it.
# The aws provider is mocked. curl_command is the fake curl, so the post-back sends nothing.

mock_provider "aws" {}

override_resource {
  target = random_id.suffix
  values = {
    hex = "a1b2c3d4"
  }
}

variables {
  api_base       = "https://api.example.com"
  org_slug       = "acme"
  account_row_id = 42
  external_id    = "0123456789abcdef0123456789abcdef"
  connect_token  = "tok-placeholder-1234"
  broker_role_arns = [
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-scheduler",
  ]
  curl_command = "FAKE_CURL_CAPTURE=./tests/.capture/slr.log ./tests/fake_curl.sh"
}

run "first_apply_creates_all_roles" {
  command = apply

  override_data {
    target = data.aws_iam_roles.spot
    values = {
      names = []
    }
  }

  override_data {
    target = data.aws_iam_roles.fleet
    values = {
      names = []
    }
  }

  override_data {
    target = data.aws_iam_roles.servicequotas
    values = {
      names = []
    }
  }

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 1 && length(aws_iam_service_linked_role.fleet) == 1 && length(aws_iam_service_linked_role.servicequotas) == 1
    error_message = "a fresh account must get all three roles"
  }

  assert {
    condition     = aws_iam_service_linked_role.spot[0].description == "Created by the Multicloud connect module (connection 42)" && aws_iam_service_linked_role.fleet[0].description == "Created by the Multicloud connect module (connection 42)" && aws_iam_service_linked_role.servicequotas[0].description == "Created by the Multicloud connect module (connection 42)"
    error_message = "the module must mark the roles it creates with the marker of this connection"
  }
}

# Second apply in the same state: the lookup now finds the roles that the module created.
run "reapply_keeps_module_created_roles" {
  command = apply

  variables {
    regions = ["us-east-1"]
  }

  override_data {
    target = data.aws_iam_roles.spot
    values = {
      names = ["AWSServiceRoleForEC2Spot"]
    }
  }

  override_data {
    target = data.aws_iam_roles.fleet
    values = {
      names = ["AWSServiceRoleForEC2Fleet"]
    }
  }

  override_data {
    target = data.aws_iam_roles.servicequotas
    values = {
      names = ["AWSServiceRoleForServiceQuotas"]
    }
  }

  override_data {
    target = data.aws_iam_role.spot
    values = {
      description = "Created by the Multicloud connect module (connection 42)"
    }
  }

  override_data {
    target = data.aws_iam_role.fleet
    values = {
      description = "Created by the Multicloud connect module (connection 42)"
    }
  }

  override_data {
    target = data.aws_iam_role.servicequotas
    values = {
      description = "Created by the Multicloud connect module (connection 42)"
    }
  }

  # A destroy would leave zero instances after the apply.
  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 1 && length(aws_iam_service_linked_role.fleet) == 1 && length(aws_iam_service_linked_role.servicequotas) == 1
    error_message = "re-apply must keep the roles that the module created"
  }
}

# manage_service_linked_roles = false: the account gets these roles in another way. The module
# plans no service-linked role, whatever the account has.
run "unmanaged_plans_no_roles" {
  command = plan

  variables {
    manage_service_linked_roles = false
  }

  override_data {
    target = data.aws_iam_roles.spot
    values = {
      names = ["AWSServiceRoleForEC2Spot"]
    }
  }

  override_data {
    target = data.aws_iam_roles.fleet
    values = {
      names = ["AWSServiceRoleForEC2Fleet"]
    }
  }

  override_data {
    target = data.aws_iam_roles.servicequotas
    values = {
      names = ["AWSServiceRoleForServiceQuotas"]
    }
  }

  override_data {
    target = data.aws_iam_role.spot
    values = {
      description = "Created by the Multicloud connect module"
    }
  }

  override_data {
    target = data.aws_iam_role.fleet
    values = {
      description = "Created by the Multicloud connect module"
    }
  }

  override_data {
    target = data.aws_iam_role.servicequotas
    values = {
      description = "Created by the Multicloud connect module"
    }
  }

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 0 && length(aws_iam_service_linked_role.fleet) == 0 && length(aws_iam_service_linked_role.servicequotas) == 0
    error_message = "manage_service_linked_roles = false must plan no service-linked role"
  }
}

# A role that someone else created (other description): the module plans no resource for it.
run "foreign_roles_are_left_alone" {
  command = plan

  override_data {
    target = data.aws_iam_roles.spot
    values = {
      names = ["AWSServiceRoleForEC2Spot"]
    }
  }

  override_data {
    target = data.aws_iam_roles.fleet
    values = {
      names = ["AWSServiceRoleForEC2Fleet"]
    }
  }

  override_data {
    target = data.aws_iam_roles.servicequotas
    values = {
      names = ["AWSServiceRoleForServiceQuotas"]
    }
  }

  override_data {
    target = data.aws_iam_role.spot
    values = {
      description = "Allows EC2 Spot to launch and manage spot instance lifecycle on your behalf."
    }
  }

  override_data {
    target = data.aws_iam_role.fleet
    values = {
      description = "Allows EC2 Fleet to launch and manage instances on your behalf."
    }
  }

  override_data {
    target = data.aws_iam_role.servicequotas
    values = {
      description = "A service-linked role required for Service Quotas to access your service quotas."
    }
  }

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 0 && length(aws_iam_service_linked_role.fleet) == 0 && length(aws_iam_service_linked_role.servicequotas) == 0
    error_message = "a role with another description is not ours and must not be managed"
  }
}

# The 1.0.2 -> 1.0.3 upgrade: the module already made the EC2 Spot and Fleet roles, and the
# account has no Service Quotas role yet. The module keeps the two and adds the third.
run "upgrade_adds_only_the_service_quotas_role" {
  command = plan

  override_data {
    target = data.aws_iam_roles.spot
    values = {
      names = ["AWSServiceRoleForEC2Spot"]
    }
  }

  override_data {
    target = data.aws_iam_roles.fleet
    values = {
      names = ["AWSServiceRoleForEC2Fleet"]
    }
  }

  override_data {
    target = data.aws_iam_roles.servicequotas
    values = {
      names = []
    }
  }

  override_data {
    target = data.aws_iam_role.spot
    values = {
      description = "Created by the Multicloud connect module"
    }
  }

  override_data {
    target = data.aws_iam_role.fleet
    values = {
      description = "Created by the Multicloud connect module"
    }
  }

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 1 && length(aws_iam_service_linked_role.fleet) == 1 && length(aws_iam_service_linked_role.servicequotas) == 1
    error_message = "the upgrade must keep the EC2 roles and add the Service Quotas role"
  }

  assert {
    condition     = length(data.aws_iam_role.servicequotas) == 0
    error_message = "an absent Service Quotas role must not be looked up by name"
  }
}

# Another instance of this module (1.1.1 or later), for another connection, created the
# Service Quotas role; the account has no EC2 Spot or Fleet role. The module must create the
# two missing roles and leave the Service Quotas role alone (it belongs to the other state).
run "other_connection_role_is_left_alone_missing_roles_are_created" {
  command = plan

  override_data {
    target = data.aws_iam_roles.spot
    values = {
      names = []
    }
  }

  override_data {
    target = data.aws_iam_roles.fleet
    values = {
      names = []
    }
  }

  override_data {
    target = data.aws_iam_roles.servicequotas
    values = {
      names = ["AWSServiceRoleForServiceQuotas"]
    }
  }

  override_data {
    target = data.aws_iam_role.servicequotas
    values = {
      description = "Created by the Multicloud connect module (connection 7)"
    }
  }

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 1 && length(aws_iam_service_linked_role.fleet) == 1
    error_message = "absent EC2 Spot and Fleet roles must be created, whatever the other roles are"
  }

  assert {
    condition     = length(aws_iam_service_linked_role.servicequotas) == 0
    error_message = "a role with the marker of another connection belongs to another state and must not be created again"
  }
}

# Upgrade from 1.1.0 or older: the state holds roles with the old fixed marker. The module
# keeps them (no destroy) and rewrites the description to the marker of this connection.
run "upgrade_keeps_roles_with_the_legacy_marker" {
  command = plan

  override_data {
    target = data.aws_iam_roles.spot
    values = {
      names = ["AWSServiceRoleForEC2Spot"]
    }
  }

  override_data {
    target = data.aws_iam_roles.fleet
    values = {
      names = ["AWSServiceRoleForEC2Fleet"]
    }
  }

  override_data {
    target = data.aws_iam_roles.servicequotas
    values = {
      names = ["AWSServiceRoleForServiceQuotas"]
    }
  }

  override_data {
    target = data.aws_iam_role.spot
    values = {
      description = "Created by the Multicloud connect module"
    }
  }

  override_data {
    target = data.aws_iam_role.fleet
    values = {
      description = "Created by the Multicloud connect module"
    }
  }

  override_data {
    target = data.aws_iam_role.servicequotas
    values = {
      description = "Created by the Multicloud connect module"
    }
  }

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 1 && length(aws_iam_service_linked_role.fleet) == 1 && length(aws_iam_service_linked_role.servicequotas) == 1
    error_message = "an upgrade must keep the roles with the legacy marker"
  }

  assert {
    condition     = aws_iam_service_linked_role.servicequotas[0].description == "Created by the Multicloud connect module (connection 42)"
    error_message = "the upgrade must move the role to the marker of this connection"
  }
}

# The documented limit, and the live case of 2026-11-10 (dev2): another folder created the
# Service Quotas role with module 1.0.3 (fixed legacy marker), and the account has no EC2
# Spot or Fleet role. The module cannot tell that role from one that this state holds, so it
# plans all three; AWS then refuses the Service Quotas create with "already exists".
# Remedy (README, CHANGELOG): apply 1.1.1 first in the folder that created the role, which
# rewrites its marker to that connection. This run pins the behavior so that a change to it
# is a decision, not an accident.
run "legacy_marker_from_another_folder_still_plans_a_create" {
  command = plan

  override_data {
    target = data.aws_iam_roles.spot
    values = {
      names = []
    }
  }

  override_data {
    target = data.aws_iam_roles.fleet
    values = {
      names = []
    }
  }

  override_data {
    target = data.aws_iam_roles.servicequotas
    values = {
      names = ["AWSServiceRoleForServiceQuotas"]
    }
  }

  override_data {
    target = data.aws_iam_role.servicequotas
    values = {
      description = "Created by the Multicloud connect module"
    }
  }

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 1 && length(aws_iam_service_linked_role.fleet) == 1 && length(aws_iam_service_linked_role.servicequotas) == 1
    error_message = "a role with the legacy marker counts as this module's own; the missing roles are still created"
  }
}

# One folder per connection. A new account_row_id in a folder that created the roles under
# another connection makes those roles foreign, so the plan destroys them (README, "Keep the
# Terraform state"). This run pins that behavior so that a change to it is a decision.
run "new_connection_in_old_folder_plans_to_destroy_its_roles" {
  command = plan

  variables {
    account_row_id = 43
  }

  override_data {
    target = data.aws_iam_roles.spot
    values = {
      names = ["AWSServiceRoleForEC2Spot"]
    }
  }

  override_data {
    target = data.aws_iam_roles.fleet
    values = {
      names = ["AWSServiceRoleForEC2Fleet"]
    }
  }

  override_data {
    target = data.aws_iam_roles.servicequotas
    values = {
      names = ["AWSServiceRoleForServiceQuotas"]
    }
  }

  override_data {
    target = data.aws_iam_role.spot
    values = {
      description = "Created by the Multicloud connect module (connection 42)"
    }
  }

  override_data {
    target = data.aws_iam_role.fleet
    values = {
      description = "Created by the Multicloud connect module (connection 42)"
    }
  }

  override_data {
    target = data.aws_iam_role.servicequotas
    values = {
      description = "Created by the Multicloud connect module (connection 42)"
    }
  }

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 0 && length(aws_iam_service_linked_role.fleet) == 0 && length(aws_iam_service_linked_role.servicequotas) == 0
    error_message = "roles marked with another connection are not this folder's roles"
  }
}
