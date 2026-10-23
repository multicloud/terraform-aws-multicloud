# One-time post-back: tells the Multicloud API the role ARN, the policy version and the
# module version. The module never sends a key or a secret.
#
# - The connect token reaches curl through the environment (MC_CONNECT_TOKEN) and a curl
#   config file on stdin. It is never an argument, so `ps` cannot show it.
# - triggers_replace holds only a hash of the token. A change of regions or of any other input
#   does not post again. A new token does.
# - Only an HTTP 2xx answer counts as success. On any other result the command prints the
#   server body and the fallback. Neither contains the token.

resource "terraform_data" "connect" {
  triggers_replace = [sha256(var.connect_token)]

  # Post only after the permissions exist: the policy is attached and the service-linked roles are ready.
  depends_on = [
    aws_iam_role_policy.provisioner,
    aws_iam_service_linked_role.spot,
    aws_iam_service_linked_role.fleet,
  ]

  provisioner "local-exec" {
    environment = {
      MC_CONNECT_TOKEN = var.connect_token
      MC_URL           = "${trimsuffix(var.api_base, "/")}/api/v1/orgs/${var.org_slug}/cloud-accounts/${var.account_row_id}/connect"
      MC_BODY = jsonencode({
        role_arn       = aws_iam_role.provisioner.arn
        policy_version = local.bundle.policy_version
        module_version = local.module_version
      })
    }

    # Only a 2xx answer counts as success. curl does not follow redirects (no -L), and
    # --fail-with-body fails only on 400 and above, so the script reads the status code (-w)
    # and the body goes to a temp file (-o). On any other result the script prints the body
    # and the fallback. In this HCL heredoc, %% writes a literal %.
    command = <<-EOT
      body_file="$(mktemp)" || exit 1
      trap 'rm -f "$body_file"' EXIT
      rc=0
      code="$(printf 'header = "X-Multicloud-Connect-Token: %s"\n' "$MC_CONNECT_TOKEN" | ${var.curl_command} --fail-with-body -sS -X POST -H "Content-Type: application/json" --data "$MC_BODY" -o "$body_file" -w '%%{http_code}' -K - "$MC_URL")" || rc=$?
      case "$code" in
        2??) [ "$rc" -eq 0 ] && exit 0 ;;
      esac
      cat "$body_file" >&2
      echo >&2
      echo "post-back failed (HTTP status: $${code:-none}); run: mctl cloud-account connect ${var.account_row_id} --from-terraform-output" >&2
      exit 1
    EOT
  }
}
