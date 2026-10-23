# FAILS BY DESIGN. The server rejects the post-back (curl exits 22), so apply must fail.
# Do not run it with the normal suite: tests/check_post_failure.sh runs it and asserts the
# error text (Review Focus 5: the server message and the fallback, never the token).

mock_provider "aws" {}

variables {
  api_base       = "https://api.example.com"
  org_slug       = "acme"
  account_row_id = 42
  external_id    = "0123456789abcdef0123456789abcdef"
  connect_token  = "tok-secret-DDDD4444"
  broker_role_arns = [
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-scheduler",
  ]
  curl_command = "FAKE_CURL_CAPTURE=./tests/.capture/failure.log FAKE_CURL_EXIT=22 ./tests/fake_curl.sh"
}

run "post_rejected" {
  command = apply

  override_resource {
    target = random_id.suffix
    values = {
      hex = "a1b2c3d4"
    }
  }
}
