# Changelog

## 1.0.0

First release of the AWS connect module.

- Creates the role `MulticloudProvisioner-<8 hex>`. Only the Multicloud broker roles that you list can assume it, and only with your ExternalId.
- Attaches the permission bundle (`policy_version` 2) as an inline policy. Optional `regions` adds one deny for all other regions. `ec2:DescribeRegions` stays allowed.
- Optional `ebs_kms_key_arns` adds KMS permissions for customer-managed EBS keys (R12).
- Creates the EC2 Spot and EC2 Fleet service-linked roles when the account has none. Set `manage_service_linked_roles = false` for a second instance in the same account, or after a loss of state.
- Posts `role_arn`, `policy_version` and `module_version` once to the Multicloud API. Only an HTTP 2xx answer counts as success. A new `connect_token` posts again. A change of `regions` does not.
