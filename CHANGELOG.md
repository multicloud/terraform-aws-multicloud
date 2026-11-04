# Changelog

The Google Cloud module (`gcp/`) has its own `gcp/CHANGELOG.md`. The versions below are the AWS module.

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
