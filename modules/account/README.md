# Multicloud AWS account submodule

Creates a new AWS account for Multicloud in your AWS Organizations (`aws_organizations_account`).
Registry source: `multicloud/multicloud/aws//modules/account`.

Run it with your management account credentials. Multicloud never gets them.

| Input | Meaning |
|---|---|
| `name` | Account display name, 1 to 50 characters |
| `email` | Email of the new account. No other AWS account may use it |
| `parent_id` | Optional. Organizational unit or root that gets the account |

| Output | Meaning |
|---|---|
| `account_id` | The 12-digit ID of the new account |
| `admin_role_arn` | `OrganizationAccountAccessRole` in the new account. Use it in a provider `assume_role` block |

`terraform destroy` closes the account (`close_on_deletion = true`). AWS keeps a closed account for 90 days.
The email of a closed account cannot open a new AWS account. See the main README, section "Destroy".

Example: `examples/aws-new-account/main.tf`.
