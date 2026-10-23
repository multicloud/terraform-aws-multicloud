# No output is sensitive and none holds the connect token. The `mctl cloud-account connect
# --from-terraform-output` fallback reads these three values.

output "role_arn" {
  description = "ARN of the role that Multicloud assumes."
  value       = aws_iam_role.provisioner.arn
}

output "policy_version" {
  description = "Version of the permission bundle in this module release."
  value       = local.bundle.policy_version
}

output "module_version" {
  description = "Version of this module."
  value       = local.module_version
}
