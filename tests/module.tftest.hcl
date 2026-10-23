# Offline tests: the aws provider is mocked, nothing reaches AWS.
# Run from deploy/customer-terraform/aws: tofu init -backend=false && tofu test

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
  connect_token  = "tok-placeholder"
  broker_role_arns = [
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-scheduler",
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-api",
  ]
}

run "role_trusts_only_broker_with_external_id" {
  command = plan

  assert {
    condition     = length(jsondecode(aws_iam_role.provisioner.assume_role_policy).Statement) == 1
    error_message = "the trust policy must have exactly one statement"
  }

  assert {
    condition     = jsonencode(jsondecode(aws_iam_role.provisioner.assume_role_policy).Statement[0].Principal) == jsonencode({ AWS = var.broker_role_arns })
    error_message = "Principal.AWS must be exactly the broker role ARNs"
  }

  assert {
    condition     = jsondecode(aws_iam_role.provisioner.assume_role_policy).Statement[0].Effect == "Allow"
    error_message = "the trust statement must be an Allow"
  }

  assert {
    condition     = jsonencode(jsondecode(aws_iam_role.provisioner.assume_role_policy).Statement[0].Action) == jsonencode(["sts:AssumeRole", "sts:SetSourceIdentity", "sts:TagSession"])
    error_message = "the trust actions must be AssumeRole, SetSourceIdentity and TagSession"
  }

  assert {
    condition     = jsonencode(jsondecode(aws_iam_role.provisioner.assume_role_policy).Statement[0].Condition) == jsonencode({ StringEquals = { "sts:ExternalId" = var.external_id } })
    error_message = "the only trust condition must be sts:ExternalId == var.external_id"
  }

  assert {
    condition     = aws_iam_role.provisioner.max_session_duration == 3600
    error_message = "max_session_duration must be one hour"
  }

  assert {
    condition     = aws_iam_role.provisioner.tags["multicloud:managed"] == "true" && aws_iam_role.provisioner.tags["multicloud:org"] == "acme"
    error_message = "the role must carry the managed and org tags"
  }
}

run "role_name_is_provisioner_prefixed" {
  command = plan

  assert {
    condition     = aws_iam_role.provisioner.name == "MulticloudProvisioner-a1b2c3d4"
    error_message = "the role name must be MulticloudProvisioner-<8 hex>"
  }

  assert {
    condition     = length(aws_iam_role.provisioner.name) == 30
    error_message = "the role name must be 30 characters"
  }
}

run "policy_is_the_rendered_bundle" {
  command = plan

  variables {
    regions          = []
    ebs_kms_key_arns = []
  }

  assert {
    condition     = jsonencode(jsondecode(aws_iam_role_policy.provisioner.policy)) == jsonencode(jsondecode(file("policy.customer.json")).document)
    error_message = "with no regions and no KMS keys the role policy must equal the bundle document"
  }

  assert {
    condition     = output.policy_version == jsondecode(file("policy.customer.json")).policy_version
    error_message = "policy_version must come from the bundle"
  }
}

run "regions_add_one_deny_with_describe_regions_exempt" {
  command = plan

  variables {
    regions = ["us-east-1", "eu-west-1"]
  }

  assert {
    condition     = length(jsondecode(aws_iam_role_policy.provisioner.policy).Statement) == length(jsondecode(file("policy.customer.json")).document.Statement) + 1
    error_message = "regions must add exactly one statement"
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.provisioner.policy).Statement[length(jsondecode(aws_iam_role_policy.provisioner.policy).Statement) - 1].Effect == "Deny"
    error_message = "the region statement must be a Deny"
  }

  assert {
    condition     = jsonencode(jsondecode(aws_iam_role_policy.provisioner.policy).Statement[length(jsondecode(aws_iam_role_policy.provisioner.policy).Statement) - 1].NotAction) == jsonencode(["ec2:DescribeRegions"])
    error_message = "the deny must exempt only ec2:DescribeRegions"
  }

  assert {
    condition     = jsondecode(aws_iam_role_policy.provisioner.policy).Statement[length(jsondecode(aws_iam_role_policy.provisioner.policy).Statement) - 1].Resource == "*"
    error_message = "the deny must cover Resource *"
  }

  assert {
    condition     = jsonencode(jsondecode(aws_iam_role_policy.provisioner.policy).Statement[length(jsondecode(aws_iam_role_policy.provisioner.policy).Statement) - 1].Condition) == jsonencode({ StringNotEquals = { "aws:RequestedRegion" = ["us-east-1", "eu-west-1"] } })
    error_message = "the deny must fire when aws:RequestedRegion is outside the list"
  }
}

run "ebs_kms_statement_only_when_keys_given" {
  command = plan

  variables {
    ebs_kms_key_arns = []
  }

  assert {
    condition     = !strcontains(aws_iam_role_policy.provisioner.policy, "kms:")
    error_message = "no kms action may appear without ebs_kms_key_arns"
  }
}

run "ebs_kms_statements_for_given_key" {
  command = plan

  variables {
    ebs_kms_key_arns = ["arn:aws:kms:us-east-1:111122223333:key/11111111-2222-3333-4444-555555555555"]
  }

  assert {
    condition     = length(jsondecode(aws_iam_role_policy.provisioner.policy).Statement) == length(jsondecode(file("policy.customer.json")).document.Statement) + 2
    error_message = "one key list must add exactly two statements"
  }

  assert {
    condition = jsonencode(jsondecode(aws_iam_role_policy.provisioner.policy).Statement[length(jsondecode(file("policy.customer.json")).document.Statement)]) == jsonencode({
      Sid    = "EbsCustomerKeyUse"
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKeyWithoutPlaintext",
        "kms:ReEncryptFrom",
        "kms:ReEncryptTo",
      ]
      Resource  = ["arn:aws:kms:us-east-1:111122223333:key/11111111-2222-3333-4444-555555555555"]
      Condition = { StringLike = { "kms:ViaService" = "ec2.*.amazonaws.com" } }
    })
    error_message = "the key-use statement is wrong"
  }

  assert {
    condition = jsonencode(jsondecode(aws_iam_role_policy.provisioner.policy).Statement[length(jsondecode(file("policy.customer.json")).document.Statement) + 1]) == jsonencode({
      Sid      = "EbsCustomerKeyGrant"
      Effect   = "Allow"
      Action   = ["kms:CreateGrant"]
      Resource = ["arn:aws:kms:us-east-1:111122223333:key/11111111-2222-3333-4444-555555555555"]
      Condition = {
        StringLike = { "kms:ViaService" = "ec2.*.amazonaws.com" }
        Bool       = { "kms:GrantIsForAWSResource" = "true" }
      }
    })
    error_message = "the key-grant statement is wrong"
  }
}

run "slrs_created_when_absent" {
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

  assert {
    condition     = length(aws_iam_service_linked_role.spot) == 1 && length(aws_iam_service_linked_role.fleet) == 1
    error_message = "both service-linked roles must be created in a fresh account"
  }
}

run "slrs_skipped_when_present" {
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

  # Roles that someone else created carry the AWS description, not the module marker.
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
    error_message = "existing service-linked roles must not be created again"
  }
}

run "bad_inputs_are_rejected" {
  command = plan

  variables {
    api_base         = "http://x"
    broker_role_arns = ["arn:aws:iam::111122223333:user/multicloud-broker-prod-api"]
    external_id      = ""
  }

  expect_failures = [
    var.api_base,
    var.broker_role_arns,
    var.external_id,
  ]
}
