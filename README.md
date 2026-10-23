# Multicloud AWS connect module

This Terraform module connects one AWS account to Multicloud.
It creates a role that Multicloud assumes.
It creates no access key and no secret.

## What the module creates

- The IAM role `MulticloudProvisioner-<8 hex>`.
  - Only the Multicloud broker roles in `broker_role_arns` can assume it.
  - The caller must send your `external_id`.
  - A session lasts one hour at most.
- One inline policy on that role.
  - The policy comes from the permission bundle in `policy.customer.json`.
  - The bundle lets Multicloud create, change and delete only resources that carry the tag `multicloud:managed=true`.
  - The policy file is generated. Do not edit it.
- The service-linked roles `AWSServiceRoleForEC2Spot` and `AWSServiceRoleForEC2Fleet`.
  The module creates a role only when your account does not have it.
  A role that the module creates gets the description "Created by the Multicloud connect module".
  The module keeps such a role on later runs. It never touches a role that you or another tool created.
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

## Use

The Multicloud API returns a snippet for your account. It looks like this.
All values are placeholders.

```hcl
module "multicloud" {
  source  = "multicloud/multicloud/aws"
  version = "1.0.0"

  api_base       = "https://api.example.com"
  org_slug       = "acme"
  account_row_id = 42
  external_id    = "replace-with-the-external-id-from-the-api"
  connect_token  = var.connect_token
  broker_role_arns = [
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-scheduler",
    "arn:aws:iam::111122223333:role/multicloud-broker-prod-api",
  ]
}
```

The provider block (credentials and region) is yours. The module does not configure it.

1. Put the snippet in your Terraform code.
2. Pass the connect token as `TF_VAR_connect_token`. Do not write it in a file.
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
| `manage_service_linked_roles` | `true` | Let the module create the EC2 Spot and EC2 Fleet service-linked roles. See below. |
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

- Opt-in regions (for example `af-south-1`) are off by default. You must enable them. The role cannot enable them.
- New AWS accounts have low EC2 vCPU quotas for On-Demand and Spot. Check the quotas before you create the first pool. Multicloud will request increases in a later release.
- DNS needs no permission in your account. Pool DNS uses Multicloud records, never your Route53.

## Keep the Terraform state

The module recognizes the service-linked roles that it created by their description.
It knows which roles it owns only through the Terraform state.
Keep the state.
If the state is lost, or if a second instance of this module runs in the same account,
the module tries to create a role that already exists, and AWS rejects the call ("already exists").
In both cases set `manage_service_linked_roles = false`.
The module then plans no service-linked role.

Do not set `manage_service_linked_roles = false` on a state that holds the service-linked roles of the module.
Terraform then plans to destroy those roles.
Read the plan before you apply it. If it destroys `aws_iam_service_linked_role`, set the value back to `true`.

## Remove access

Run `terraform destroy`.
The role and its policy are deleted, and Multicloud cannot assume the role again.
Terraform deletes a service-linked role only when it carries the description "Created by the Multicloud connect module".
A role that the account already had stays.
AWS refuses to delete a service-linked role that a resource still uses.
Resources that Multicloud created in your account stay.
Delete them first (delete the pool in Multicloud), or find them by the tag `multicloud:managed=true`.

## Recommendation: use a dedicated AWS account

Use an account that holds only Multicloud resources.
The tag condition limits the role, but a dedicated account gives a clear cost view and a clear boundary.
Delete the account to remove everything.

## Versions

Each release has a version tag `v<module_version>`.
Pin the version with the `version` argument of the module block. The module is in the Terraform and OpenTofu registries as `multicloud/multicloud/aws`. The source is the public repository `github.com/multicloud/terraform-aws-multicloud`.
The changes of each release are in `CHANGELOG.md`.
