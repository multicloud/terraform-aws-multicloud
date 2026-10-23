# Post-back tests. The aws provider is mocked and curl is replaced by tests/fake_curl.sh,
# so no network call happens. The local-exec provisioner does run, in the module directory.
# A failing post-back cannot be expected inside tofu test (a provisioner error is not a
# checkable-object failure). tests/failure/*.tftest.hcl fail by design and
# tests/check_post_failure.sh asserts their error text. `tofu test` does NOT run that script.
# Run it by hand from deploy/customer-terraform/aws, after `tofu init -backend=false`:
#   tests/check_post_failure.sh   (prints "ok post_rejected" and "ok no_curl")
# The first run deletes the capture file; later runs count the calls in it.

mock_provider "aws" {}

# The overrides sit in each run that applies the module (the capture reader has no such resources).

variables {
  api_base       = "https://api.example.com"
  org_slug       = "acme"
  account_row_id = 42
  external_id    = "0123456789abcdef0123456789abcdef"
  connect_token  = "tok-first-AAAA1111"
  broker_role_arns = [
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-scheduler",
  ]
  curl_command = "FAKE_CURL_CAPTURE=./tests/.capture/calls.log ./tests/fake_curl.sh"
}

run "reset" {
  command = apply

  module {
    source = "./tests/reset"
  }

  variables {
    path = "./tests/.capture/calls.log"
  }
}

run "first_apply" {
  command = apply

  override_resource {
    target = random_id.suffix
    values = {
      hex = "a1b2c3d4"
    }
  }

  override_resource {
    target = aws_iam_role.provisioner
    values = {
      arn = "arn:aws:iam::999988887777:role/MulticloudProvisioner-a1b2c3d4"
    }
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
}

run "posts_identifiers_with_token_in_env_not_argv" {
  command = plan

  module {
    source = "./tests/capture"
  }

  variables {
    path = "./tests/.capture/calls.log"
  }

  assert {
    condition     = output.calls == 1
    error_message = "the first apply must post exactly once"
  }

  assert {
    condition     = !strcontains(output.argv, "tok-first-AAAA1111")
    error_message = "the token must never appear in argv"
  }

  assert {
    condition     = output.last_token == "tok-first-AAAA1111"
    error_message = "the token must reach curl through the MC_CONNECT_TOKEN environment variable"
  }

  assert {
    condition     = output.last_url == "https://api.example.com/api/v1/orgs/acme/cloud-accounts/42/connect"
    error_message = "the URL is {api_base}/api/v1/orgs/{org_slug}/cloud-accounts/{account_row_id}/connect"
  }

  assert {
    condition     = jsonencode(sort(keys(output.last_body))) == jsonencode(["module_version", "policy_version", "role_arn"])
    error_message = "the body must hold exactly role_arn, policy_version and module_version"
  }

  assert {
    condition     = output.last_body.role_arn == "arn:aws:iam::999988887777:role/MulticloudProvisioner-a1b2c3d4" && output.last_body.module_version == "1.0.0"
    error_message = "the body must carry the role ARN and the module version"
  }

  assert {
    condition     = strcontains(output.argv, "ARGV --fail-with-body") && !strcontains(output.argv, "X-Multicloud-Connect-Token")
    error_message = "curl must run with --fail-with-body and the token header must not be an argument"
  }

  assert {
    condition     = output.last_stdin == "header = \"X-Multicloud-Connect-Token: tok-first-AAAA1111\""
    error_message = "the token header must reach curl through its config file on stdin"
  }
}

run "apply_regions_change" {
  command = apply

  override_resource {
    target = random_id.suffix
    values = {
      hex = "a1b2c3d4"
    }
  }

  override_resource {
    target = aws_iam_role.provisioner
    values = {
      arn = "arn:aws:iam::999988887777:role/MulticloudProvisioner-a1b2c3d4"
    }
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

  variables {
    regions = ["us-east-1"]
  }
}

run "regions_change_does_not_repost" {
  command = plan

  module {
    source = "./tests/capture"
  }

  variables {
    path = "./tests/.capture/calls.log"
  }

  assert {
    condition     = output.calls == 1
    error_message = "a regions-only change must not post again"
  }
}

run "apply_new_token" {
  command = apply

  override_resource {
    target = random_id.suffix
    values = {
      hex = "a1b2c3d4"
    }
  }

  override_resource {
    target = aws_iam_role.provisioner
    values = {
      arn = "arn:aws:iam::999988887777:role/MulticloudProvisioner-a1b2c3d4"
    }
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

  variables {
    connect_token = "tok-second-BBBB2222"
  }
}

run "new_token_reposts" {
  command = plan

  module {
    source = "./tests/capture"
  }

  variables {
    path = "./tests/.capture/calls.log"
  }

  assert {
    condition     = output.calls == 2
    error_message = "a new connect token must post again"
  }

  assert {
    condition     = output.last_token == "tok-second-BBBB2222"
    error_message = "the second post must carry the new token"
  }

  assert {
    condition     = !strcontains(output.argv, "tok-second-BBBB2222")
    error_message = "the token must never appear in argv"
  }
}
