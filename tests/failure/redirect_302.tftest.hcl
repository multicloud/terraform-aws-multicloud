# FAILS BY DESIGN. The server answers 302 and curl exits 0. A 3xx answer is not a success:
# apply must fail, show the server body and the fallback, and never show the token.
# tests/check_post_failure.sh runs it and asserts the error text.

mock_provider "aws" {}

variables {
  api_base       = "https://api.example.com"
  org_slug       = "acme"
  account_row_id = 42
  external_id    = "0123456789abcdef0123456789abcdef"
  connect_token  = "tok-secret-FFFF6666"
  broker_role_arns = [
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-scheduler",
  ]
  curl_command = "FAKE_CURL_CAPTURE=./tests/.capture/failure.log FAKE_CURL_EXIT=0 FAKE_CURL_HTTP_CODE=302 ./tests/fake_curl.sh"
}

run "redirect_302" {
  command = apply

  override_resource {
    target = random_id.suffix
    values = {
      hex = "a1b2c3d4"
    }
  }
}
