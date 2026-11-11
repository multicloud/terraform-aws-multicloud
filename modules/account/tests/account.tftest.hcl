# Offline test: the aws provider is mocked, so no AWS call happens.

mock_provider "aws" {
  mock_data "aws_partition" {
    defaults = {
      partition = "aws"
    }
  }

  mock_resource "aws_organizations_account" {
    defaults = {
      id = "444455556666"
    }
  }
}

variables {
  name  = "multicloud-acme-42"
  email = "you+multicloud@company.com"
}

run "outputs_and_settings" {
  command = apply

  assert {
    condition     = aws_organizations_account.this.role_name == "OrganizationAccountAccessRole" && aws_organizations_account.this.close_on_deletion == true
    error_message = "the account must use the standard admin role name and close on deletion"
  }

  assert {
    condition     = output.account_id == "444455556666"
    error_message = "account_id must come from the account resource"
  }

  assert {
    condition     = output.admin_role_arn == "arn:aws:iam::444455556666:role/OrganizationAccountAccessRole"
    error_message = "admin_role_arn must name OrganizationAccountAccessRole in the new account"
  }
}

run "parent_id_is_optional" {
  command = plan

  assert {
    condition     = var.parent_id == null
    error_message = "parent_id must default to null"
  }
}

run "bad_email_is_refused" {
  command = plan

  variables {
    email = "not-an-email"
  }

  expect_failures = [var.email]
}

run "empty_name_is_refused" {
  command = plan

  variables {
    name = ""
  }

  expect_failures = [var.name]
}

run "long_name_is_refused" {
  command = plan

  variables {
    name = "0123456789012345678901234567890123456789012345678901"
  }

  expect_failures = [var.name]
}
