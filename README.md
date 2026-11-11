# Multicloud AWS connect module

This Terraform module connects one AWS account to Multicloud.
It creates a role that Multicloud assumes.
It creates no access key and no secret.

The Google Cloud module is in `gcp/`. Its own `gcp/README.md` and `gcp/CHANGELOG.md` describe it.
The Azure module is in `azure/`. Its own `azure/README.md` and `azure/CHANGELOG.md` describe it.
The rest of this file describes the AWS module.

## What the module creates

- The IAM role `MulticloudProvisioner-<8 hex>`.
  - Only the Multicloud broker roles in `broker_role_arns` can assume it.
  - The caller must send your `external_id`.
  - A session lasts one hour at most.
- One inline policy on that role.
  - The policy comes from the permission bundle in `policy.customer.json`.
  - The bundle lets Multicloud create, change and delete only resources that carry the tag `multicloud:managed=true`.
  - The policy file is generated. Do not edit it.
- The service-linked roles `AWSServiceRoleForEC2Spot`, `AWSServiceRoleForEC2Fleet` and `AWSServiceRoleForServiceQuotas`.
  The module decides each role on its own. It creates a role only when your account does not have it.
  A role that the module creates gets the description "Created by the Multicloud connect module (connection <account_row_id>)".
  The module keeps such a role on later runs.
  It never touches a role that you, another tool, or the module for another connection created.
- One call to the Multicloud API, after the role exists.
  The call sends `role_arn`, `policy_version` and `module_version`.
  The call sends the connect token in an HTTP header.

## What the module never creates

- No IAM user.
- No access key.
- No secret of any kind.
- No output holds the connect token.

## Requirements

- Terraform 1.5.0 or later, or OpenTofu 1.6.0 or later.
- The AWS provider `hashicorp/aws` 6.x, configured by you (credentials and region).
- `curl` 7.76.0 or later in the `PATH`.
- A Linux or macOS shell (`/bin/sh`). Windows needs WSL.
- Network access from the machine that runs `apply` to the Multicloud API.
- Path A also needs management account permissions. See "Requirement: a new AWS account for Multicloud".
- The identity that runs `apply` may create IAM roles and policies, and create service-linked roles (`iam:CreateServiceLinkedRole`). The upgrade from 1.1.0 or older to 1.1.1 also changes the description of the service-linked roles that the module created (`iam:UpdateRole`). An administrator has these permissions.

## Use

`POST /api/v1/orgs/{slug}/cloud-accounts` (or `mctl cloud-account create`) returns a ready snippet.
The API fills in every value: the API base, the org slug, the account row ID, the external ID, the broker role ARNs,
the regions and the module version. You do not fill in values by hand.
The snippet looks like this. All values are placeholders.

```hcl
variable "multicloud_connect_token" {
  type      = string
  sensitive = true
}

module "multicloud" {
  source  = "multicloud/multicloud/aws"
  version = "1.3.1"

  api_base         = "https://api.example.com"
  org_slug         = "acme"
  account_row_id   = 42
  external_id      = "replace-with-the-external-id-from-the-api"
  broker_role_arns = [
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-scheduler",
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-api",
  ]
  regions          = ["us-east-1"]
  connect_token    = var.multicloud_connect_token
}

# The fallback "mctl cloud-account connect --from-terraform-output" reads these.
output "role_arn" {
  value = module.multicloud.role_arn
}

output "policy_version" {
  value = module.multicloud.policy_version
}

output "module_version" {
  value = module.multicloud.module_version
}
```

The provider block (credentials and region) is yours. The module does not configure it.

1. Put the snippet in your Terraform code.
2. Pass the connect token as `TF_VAR_multicloud_connect_token`. Do not write it in a file.
3. Run `terraform init`, then `terraform apply`.

If the post to the Multicloud API fails, `apply` fails.
Only an HTTP 2xx answer counts as success. A redirect is a failure.
The error shows the message from the server.
It also shows this fallback command, which sends the same values from the module outputs:
`mctl cloud-account connect <id> --from-terraform-output`.
The error never contains the connect token.

To connect again with a new token, change `connect_token` and run `apply`.
A change of any other input does not post again.

## Inputs

| Name | Default | Meaning |
|---|---|---|
| `api_base` | none | URL of the Multicloud API. It must start with `https://`. |
| `org_slug` | none | Your organization slug. |
| `account_row_id` | none | Number of the cloud account row. |
| `external_id` | none | ExternalId from the API. 32 to 128 characters. |
| `connect_token` | none | One-time token from the API. Sensitive. |
| `broker_role_arns` | none | 1 to 4 Multicloud broker role ARNs. |
| `regions` | `[]` | Allowed regions. An empty list allows every region. |
| `ebs_kms_key_arns` | `[]` | Customer-managed KMS keys for EBS. See below. |
| `manage_service_linked_roles` | `true` | Let the module create the EC2 Spot, EC2 Fleet and Service Quotas service-linked roles that your account does not have. Set `false` only when you create all three roles in another way. See below. |
| `source_identities` | `["scheduler", "api-server"]` | Source identities that the trust policy allows. Keep the default unless Multicloud tells you to change it. |
| `post_back` | `true` | Send the one-time post-back. Keep the default unless Multicloud tells you to change it. |
| `curl_command` | `curl` | Test only. Do not change it. |

## Outputs

| Name | Meaning |
|---|---|
| `role_arn` | ARN of the role that Multicloud assumes. |
| `policy_version` | Version of the permission bundle. |
| `module_version` | Version of this module. |

## Limit Multicloud to some regions

Set `regions = ["us-east-1", "eu-west-1"]`.
The policy then denies every action outside these regions.
The call `ec2:DescribeRegions` stays allowed in every region.
The connection check and the scheduler need it.
The calls `account:ListRegions`, `account:GetRegionOptStatus` and `account:EnableRegion` also stay allowed.
The Account Management API answers only in `us-east-1`.
A second statement denies `account:EnableRegion` for every region outside the list (`account:TargetRegion`).
Multicloud can then turn on only the opt-in regions in your list.

## Opt-in regions

Some AWS regions (for example `af-south-1` and `ap-east-1`) are off in a new account.
AWS calls them opt-in regions.
Module 1.2.0 (policy version 4) lets Multicloud turn them on: `account:ListRegions`, `account:GetRegionOptStatus` and `account:EnableRegion`.
Multicloud turns on every opt-in region that is off (or only the regions in `regions`), unless you said no when you created the cloud account.
To say no, clear "Turn on all AWS opt-in regions in this account" on the website, or run `mctl cloud-account create --no-opt-in-regions`.

Turning on a region takes minutes to hours. AWS shows the region as `ENABLING` during that time.
Multicloud does not use a region before it is on.
When the region is on, verify the account again (`mctl cloud-account verify <id>`, or "Verify again" on the website). The verify adds the region to Multicloud.

Multicloud never turns a region off.
An organization SCP (service control policy) can deny `account:EnableRegion`. The verify then shows a warning and still passes.

## Set `ebs_kms_key_arns` when EBS uses your own key

Set `ebs_kms_key_arns` only if both statements are true:

- EBS default encryption is on in the account (or in a region that you use).
- The default key is a customer-managed KMS key, not the AWS-managed key `aws/ebs`.

Without the key permissions, every node launch fails.
Give the key ARNs, not aliases.
The role then gets these KMS actions on those keys only:
`kms:CreateGrant`, `kms:Decrypt`, `kms:DescribeKey`, `kms:GenerateDataKeyWithoutPlaintext`, `kms:ReEncryptFrom` and `kms:ReEncryptTo`.
EC2 must make the call for you (`kms:ViaService = ec2.*.amazonaws.com`).
`kms:CreateGrant` also needs `kms:GrantIsForAWSResource = true`.
The default key policy lets IAM policies grant access to the key.
If you changed the key policy to remove that, add the role ARN (output `role_arn`) to it.

If you do not set the variable, the role has no KMS permission.

## What the module does not do

These items are not IAM permissions. You must check them yourself.

- With module 1.1.1 or older (policy version 3), the role cannot turn on opt-in regions. Turn them on yourself, or upgrade to 1.2.0. See "Opt-in regions".
- New AWS accounts have low EC2 vCPU quotas for On-Demand and Spot. Check the quotas before you create the first pool. Multicloud will request increases in a later release.
- DNS needs no permission in your account. Pool DNS uses Multicloud records, never your Route53.

## Keep the Terraform state

The module recognizes the service-linked roles that it created by their description.
The description names the connection (`account_row_id`).
The module decides each role on its own:

- Your account has no such role: the module creates it.
- The role carries the description of this connection: the module keeps it.
- The role has any other description: the module leaves it alone. EC2 and Service Quotas use it as it is.

So a second instance of this module in the same account (for another connection) creates only the roles that are missing.
It needs no extra setting.

Keep the state.
If the state is lost, the module tries to create again the roles that this connection created, and AWS rejects the call ("already exists").

Use one folder for each connection.
Do not change `account_row_id` in a folder that already created service-linked roles.
The roles then carry the description of the old connection, so the plan destroys them.
For a new connection, use a new folder.

### "already exists" for a service-linked role

The apply stops with an "already exists" error for `aws_iam_service_linked_role`.
The role has the description of this connection, or the description "Created by the Multicloud connect module" of module 1.1.0 and older, and this folder's state does not hold it.
Do one of these:

- The role came from another folder in this account (module 1.1.0 or older): run `terraform apply` with module 1.1.1 or later in that folder first. The apply changes the role description to the connection of that folder. Then apply this folder again.
- You lost the state of the folder that created the role, and no other folder holds the role: in the IAM console, open the role and change its description to any other text. Then apply again. The module then leaves the role alone.
  Do not do this while a folder still holds the role in its state. That folder then sees a description that is not its own, and its next plan shows a destroy of the role.
  If you see that destroy, do not apply. Change the description back to the text it had, then plan again.

Do not set `manage_service_linked_roles = false` to get past this error. With `false` the module creates none of the three roles, and spot launches fail when the account has no EC2 Spot role.
Set `false` only when you create all three roles in another way.
On a state that holds the service-linked roles of the module, `false` also plans to destroy them.
Read the plan before you apply it. If it destroys `aws_iam_service_linked_role`, set the value back to `true`.

## Remove access

Run `terraform destroy`.
The role and its policy are deleted, and Multicloud cannot assume the role again.
Terraform deletes only the service-linked roles that this folder created (the roles in its state).
A service-linked role that is not in the state of this folder stays, for example a role that the account already had or that another folder created.
A service-linked role that this folder created is deleted even when another Multicloud connection in the same account uses it.
The next `terraform apply` in the folder of that other connection creates the role again.
AWS refuses to delete a service-linked role that a resource still uses.
AWS also refuses to delete the Service Quotas role while a quota increase request is pending.
Multicloud files these requests for your pools, so the account can have some.
The destroy then stops with "Service-linked role can't be deleted because there are pending service limit increase request(s)".
Everything else is deleted already; only the Service Quotas role is left in the state.
You see the open requests in the AWS console under Service Quotas, Quota request history.
Keep the folder and its state file. After AWS closes the requests, run `terraform destroy` again in the same folder, with the same AWS credentials.
Resources that Multicloud created in your account stay.
Delete them first (delete the pool in Multicloud), or find them by the tag `multicloud:managed=true`.

## Requirement: a new AWS account for Multicloud

Multicloud works only inside the AWS account that you connect. Use a new AWS account made for Multicloud.
The tag condition limits the role, but a new account gives a clear cost view and a clear boundary.
There are three paths.

- **Path A (default): your Terraform creates the account in your AWS Organizations.**
  Run it with your management account credentials. Multicloud never gets them.
  Run `mctl cloud-account create --cloud AWS --new-account-email you+multicloud@company.com`, then `mctl cloud-account apply <id>`.
  The file runs in two stages: first the new account (submodule `modules/account`), then the Multicloud role in it.
  A complete example is in `examples/aws-new-account/main.tf`.
- **Path B: your AWS administrator creates the account.** In the AWS console, open AWS Organizations,
  then **Add an AWS account**, then **Create an AWS account**. Sign in to the new account (switch to the role
  `OrganizationAccountAccessRole`). Then run the normal snippet in it.
- **Path C: you have no AWS Organizations.** Sign up for a new standalone AWS account with an email that no other AWS account uses.
  Then run the normal snippet in it.

The email of the new account must be unused by every other AWS account.
A plus-address such as `you+multicloud@company.com` usually works.

### What path A needs in the management account

The identity that runs path A needs these permissions in the management account:

- `organizations:CreateAccount`, `organizations:DescribeCreateAccountStatus`, `organizations:DescribeAccount`
- `organizations:ListParents`, and `organizations:MoveAccount` when you set `parent_id`
- `organizations:CloseAccount` (for destroy)
- `organizations:DescribeOrganization` (the provider may read it; read access is enough)
- `sts:AssumeRole` on the new `OrganizationAccountAccessRole`

An administrator has all of them.
Multicloud gets no permission in the management account.
The Multicloud broker roles trust only the role `MulticloudProvisioner-*` in the new account.
They never assume `OrganizationAccountAccessRole`.

### When the account is not new

Multicloud checks the account at the first verify: it must be new, and no EC2 machine may run in it.
When the account is older than the connection, or machines exist, nothing is refused and nothing is connected yet.
The verify asks an organization owner of your Multicloud organization to approve.
The owner runs `mctl cloud-account accept-shared-account <id>` and types the 12-digit account ID.
Multicloud records who approved and when.

### Destroy

Every path:

- `terraform destroy` fails on `AWSServiceRoleForEC2Spot` with `Open or Active spot instance requests found` for a few minutes after the last spot instance ends. Wait 5 minutes and run it again.

Path A:

- `mctl cloud-account destroy <id>` removes the Multicloud role from the state and closes the account.
- By hand: run `terraform state rm module.multicloud`, then `terraform destroy`.
  The new account is closed, so its roles go with it.
- AWS takes 10 minutes or more to close the account; Terraform waits up to 30 minutes (module 1.3.1 or later).
  If the command still reports a timeout, that is expected; nothing is broken.
  The account is closed when the AWS console shows it as Closed. Then run `terraform state rm module.multicloud_account`.
- AWS keeps a closed account for 90 days. Its email cannot be used for a new AWS account in that time.
  `CloseAccount` has a quota of closures in a rolling 30 days.

Paths B and C: run `terraform destroy` in the folder, then close the account in the AWS console
(path B from the management account, path C from the account itself).

## Versions

Each release has a version tag `v<module_version>`.
Pin the version with the `version` argument of the module block. The module is in the Terraform and OpenTofu registries as `multicloud/multicloud/aws`. The source is the public repository `github.com/multicloud/terraform-aws-multicloud`.
The changes of each release are in `CHANGELOG.md`.
