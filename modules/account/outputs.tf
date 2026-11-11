output "account_id" {
  description = "The 12-digit ID of the new AWS account."
  value       = aws_organizations_account.this.id
}

output "admin_role_arn" {
  description = "The role that your Terraform assumes to work inside the new account."
  value       = "arn:${data.aws_partition.current.partition}:iam::${aws_organizations_account.this.id}:role/OrganizationAccountAccessRole"
}
