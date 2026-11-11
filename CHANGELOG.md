# Changelog

The Google Cloud module (`gcp/`) has its own `gcp/CHANGELOG.md`. The Azure module (`azure/`) has its own `azure/CHANGELOG.md`. The versions below are the AWS module.

## 1.3.1

Fix: closing a new account (`modules/account`, `terraform destroy`) reported a timeout although AWS closed the account.

- AWS takes 10 minutes or more to close an account. The AWS provider waited only 10 minutes (its default) and stopped just before AWS reported the account as closed.
- The account resource now waits up to 30 minutes (`timeouts { delete = "30m" }`).
- The permission policy does not change. The policy version stays 5.

## 1.3.0

New: the submodule `modules/account` (registry source `multicloud/multicloud/aws//modules/account`) creates a new AWS account for Multicloud in your AWS Organizations (`aws_organizations_account`, `close_on_deletion = true`). It runs with your management account credentials. Outputs: `account_id` and `admin_role_arn`. The permission policy changes: the policy version is now 5.

- The role gets `account:GetAccountInformation` (statement `Read`). It is read-only and shows only the name, ID, creation date and state of the account itself.
- The new action is exempt from the Deny `DenyOutsideAllowedRegions`, because the Account Management API answers in `us-east-1`.
- Multicloud uses it at the first verify to check that the account is new.
- Upgrade: change `version` to `1.3.0` and run `mctl cloud-account apply <id>`. The command issues a new connect token, so the apply posts policy version 5 to Multicloud. A plain `tofu apply` with the old token changes the role policy but does not post.

## 1.2.0

New: Multicloud can turn on the AWS opt-in regions of the account (for example `af-south-1`). The permission policy changes: the policy version is now 4.

- The role gets `account:ListRegions`, `account:GetRegionOptStatus` and `account:EnableRegion` (statement `OptInRegions`).
- With `regions` set, a new Deny statement allows `account:EnableRegion` only for the regions in the list (condition `account:TargetRegion`). The three `account:` calls are exempt from the region Deny, because the Account Management API answers only in `us-east-1`.
- Multicloud turns on an opt-in region only when you did not say no at cloud account create. A region takes minutes to hours to turn on. Verify the account again when it is on. Multicloud never turns a region off.
- Upgrade: change `version` to `1.2.0` and run `mctl cloud-account apply <id>`. The command issues a new connect token, so the apply posts policy version 4 to Multicloud. A plain `tofu apply` with the old token changes the role policy but does not post: Multicloud then still sees policy version 3 and does not turn on regions.

## 1.1.1

Fix: in an account that already had some of the service-linked roles from another instance of this module, the apply stopped with "already exists". The documented way out, `manage_service_linked_roles = false`, then created none of the roles, and spot launches failed with `AuthFailure.ServiceLinkedRoleCreationNotPermitted`.

- The module decides each service-linked role (EC2 Spot, EC2 Fleet, Service Quotas) on its own. It creates a role when the account has none. It keeps a role that it created. It leaves every other role alone.
- The description of a role that the module creates now names the connection: "Created by the Multicloud connect module (connection <account_row_id>)". A second instance of the module, for another connection, sees those roles as not its own and creates only the missing roles.
- `manage_service_linked_roles` keeps its meaning. Set `false` only when you create all three roles in another way.
- The permission policy does not change. The policy version stays 3.
- Upgrade: change `version` to `1.1.1` and run `tofu apply` (or `terraform apply`). The apply changes the description of the roles that the module created; it does not replace them. The identity that runs the apply needs `iam:UpdateRole` on those roles (an administrator has it).
- When several folders use this module in one account, upgrade first the folder that created the service-linked roles. Until that folder runs 1.1.1, its roles still have the old description "Created by the Multicloud connect module", and another folder plans to create them again ("already exists"). The README section "already exists for a service-linked role" has the steps.

## 1.1.0

Two new optional inputs. The defaults keep the 1.0.3 behavior, so an upgrade changes nothing for a customer.

- `source_identities` (default `["scheduler", "api-server"]`): the source identities that the trust policy lets a Multicloud caller set. Each item must match `^[a-z][a-z0-9-]{1,31}$`; at least one item.
- `post_back` (default `true`): set `false` to skip the one-time post-back. The resource `terraform_data.connect` and its `triggers_replace` do not change, so the upgrade plans no replacement of it.
- The permission policy does not change. The policy version stays 3.
- Upgrade: change `version` to `1.1.0` and run `tofu apply` (or `terraform apply`).

## 1.0.3

Fix: AWS refused the first quota increase request of an account with `DependencyAccessDeniedException`.

- The module now creates the Service Quotas service-linked role (`AWSServiceRoleForServiceQuotas`) when the account has none, in the same way as the EC2 Spot and EC2 Fleet roles. AWS needs this role before it accepts a quota increase request, and the Multicloud role cannot create it.
- The permission policy does not change. The policy version stays 3.
- Upgrade: change `version` to `1.0.3` and run `tofu apply` (or `terraform apply`). The apply adds one service-linked role. The identity that runs the apply needs `iam:CreateServiceLinkedRole` for `servicequotas.amazonaws.com`, as it already does for EC2 Spot and EC2 Fleet.

## 1.0.2

Fix: Multicloud could not read your list of quota increase requests, so it could not ask AWS for spot quota without a risk of asking twice.

- The role can now list your quota increase requests (`servicequotas:ListRequestedServiceQuotaChangeHistory`). This action is read-only. AWS gives it no condition key, so it moved out of the statement that limits quota actions to EC2. Requesting an increase (`servicequotas:RequestServiceQuotaIncrease`) is still limited to EC2 quotas.
- The policy version is now 3.
- Upgrade: change `version` to `1.0.2` and run `tofu apply` (or `terraform apply`). Only the permission policy of the role changes.

## 1.0.1

Fix: Multicloud could not assume the role (AWS answered AccessDenied on `sts:SetSourceIdentity`).

- The trust policy now has two statements. `sts:AssumeRole` still needs your ExternalId. `sts:SetSourceIdentity` and `sts:TagSession` are in their own statement, because AWS checks them without the ExternalId. That statement allows only the source identities `scheduler` and `api-server`. Neither action gives access by itself.
- Upgrade: change `version` to `1.0.1` and run `tofu apply` (or `terraform apply`). Only the trust policy of the role changes.

## 1.0.0

First release of the AWS connect module.

- Creates the role `MulticloudProvisioner-<8 hex>`. Only the Multicloud broker roles that you list can assume it, and only with your ExternalId.
- Attaches the permission bundle (`policy_version` 2) as an inline policy. Optional `regions` adds one deny for all other regions. `ec2:DescribeRegions` stays allowed.
- Optional `ebs_kms_key_arns` adds KMS permissions for customer-managed EBS keys (R12).
- Creates the EC2 Spot and EC2 Fleet service-linked roles when the account has none. Set `manage_service_linked_roles = false` for a second instance in the same account, or after a loss of state.
- Posts `role_arn`, `policy_version` and `module_version` once to the Multicloud API. Only an HTTP 2xx answer counts as success. A new `connect_token` posts again. A change of `regions` does not.
