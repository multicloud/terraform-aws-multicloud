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

run "first_apply_creates_both_roles" {
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

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 1 && length(aws_iam_service_linked_role.fleet) == 1
    error_message = "a fresh account must get both roles"
  }

  assert {
    condition     = aws_iam_service_linked_role.spot[0].description == "Created by the Multicloud connect module" && aws_iam_service_linked_role.fleet[0].description == "Created by the Multicloud connect module"
    error_message = "the module must mark the roles it creates"
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

  # A destroy would leave zero instances after the apply.
  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 1 && length(aws_iam_service_linked_role.fleet) == 1
    error_message = "re-apply must keep the roles that the module created"
  }
}

# A second module instance in the same account, or a lost state: the role carries the module
# marker but this state does not know it, so a create would fail with "already exists".
# With manage_service_linked_roles = false the module plans no role and does no lookup.
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
    condition     = length(aws_iam_service_linked_role.spot) == 0 && length(aws_iam_service_linked_role.fleet) == 0
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

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 0 && length(aws_iam_service_linked_role.fleet) == 0
    error_message = "a role with another description is not ours and must not be managed"
  }
}
