# FAILS BY DESIGN. The curl command does not exist on the machine, so apply must fail.
# tests/check_post_failure.sh runs it and asserts the error text.

mock_provider "aws" {}

variables {
  api_base       = "https://api.example.com"
  org_slug       = "acme"
  account_row_id = 42
  external_id    = "0123456789abcdef0123456789abcdef"
  connect_token  = "tok-secret-EEEE5555"
  broker_role_arns = [
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-scheduler",
  ]
  curl_command = "multicloud-test-no-such-curl"
}

run "no_curl" {
  command = apply

  override_resource {
    target = random_id.suffix
    values = {
      hex = "a1b2c3d4"
    }
  }
}
