variable "api_base" {
  description = "Base URL of the Multicloud API, for example https://api.multicloud.io. The module posts the role ARN there once."
  type        = string

  validation {
    condition     = can(regex("^https://[^/\\s]+", var.api_base))
    error_message = "api_base must start with https://."
  }
}

variable "org_slug" {
  description = "Your organization slug, as the Multicloud API shows it."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9._-]*$", var.org_slug))
    error_message = "org_slug may contain only letters, digits, dot, underscore and hyphen."
  }
}

variable "account_row_id" {
  description = "Number of the cloud account row that the Multicloud API created for this AWS account."
  type        = number

  validation {
    condition     = var.account_row_id > 0 && var.account_row_id == floor(var.account_row_id)
    error_message = "account_row_id must be a positive whole number."
  }
}

variable "external_id" {
  description = "ExternalId that the Multicloud API generated. The role trusts the broker only when the caller sends this value."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_+=,.@:/-]{32,128}$", var.external_id))
    error_message = "external_id must have 32 to 128 characters from A-Z a-z 0-9 and _+=,.@:/-."
  }
}

variable "connect_token" {
  description = "One-time token that the Multicloud API generated. The module sends it once, in an HTTP header, to confirm the connection. A new token makes the module post again. The token may contain only the characters A-Z a-z 0-9 and ._~+/=:- (the module writes it into a curl config line)."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9._~+/=:-]+$", var.connect_token))
    error_message = "connect_token has characters outside A-Z a-z 0-9 and ._~+/=:-. Copy it again from the API response."
  }
}

variable "broker_role_arns" {
  description = "ARNs of the Multicloud broker roles that may assume the provisioner role. The API returns them. Use 1 to 4 items."
  type        = list(string)

  validation {
    condition     = length(var.broker_role_arns) >= 1 && length(var.broker_role_arns) <= 4
    error_message = "broker_role_arns must have 1 to 4 items."
  }

  validation {
    condition     = alltrue([for arn in var.broker_role_arns : can(regex("^arn:aws:iam::[0-9]{12}:role/multicloud-broker-[a-z0-9-]+$", arn))])
    error_message = "Each broker_role_arns item must look like arn:aws:iam::<12 digits>:role/multicloud-broker-<name>."
  }
}

variable "regions" {
  description = "AWS regions where Multicloud may act. The default, an empty list, allows every region. A non-empty list denies all other regions, except the calls ec2:DescribeRegions, account:ListRegions, account:GetRegionOptStatus and account:EnableRegion; account:EnableRegion is then allowed only for the listed regions."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for r in var.regions : can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]+$", r))])
    error_message = "Each regions item must be an AWS region name such as us-east-1."
  }
}

variable "ebs_kms_key_arns" {
  description = "ARNs of customer-managed KMS keys that encrypt EBS volumes in this account. Set it only if EBS default encryption uses such a key. The default, an empty list, adds no KMS permission."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for arn in var.ebs_kms_key_arns : can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[A-Za-z0-9-]+$", arn))])
    error_message = "Each ebs_kms_key_arns item must be a KMS key ARN (arn:aws:kms:<region>:<account>:key/<id>), not an alias."
  }
}

variable "manage_service_linked_roles" {
  description = "Whether the module creates the EC2 Spot, EC2 Fleet and Service Quotas service-linked roles that the account does not have. It decides each role on its own and leaves alone a role that another instance of the module or another tool created. Keep the default, true, and keep the Terraform state. Set false only when you create all three roles in another way: the module then plans no service-linked role."
  type        = bool
  default     = true
}

variable "curl_command" {
  description = "TEST ONLY. The command that sends the post-back. Leave the default, curl. The module tests replace it with a test double."
  type        = string
  default     = "curl"
}

variable "source_identities" {
  description = "The source identities that the trust policy lets a Multicloud caller set on its session (CloudTrail sourceIdentity). The default is right for a customer account. Change it only if Multicloud tells you to, for example to add catalog when you connect Multicloud's own account."
  type        = list(string)
  default     = ["scheduler", "api-server"]

  validation {
    condition     = length(var.source_identities) >= 1
    error_message = "source_identities needs at least one item."
  }

  validation {
    condition     = alltrue([for i in var.source_identities : can(regex("^[a-z][a-z0-9-]{1,31}$", i))])
    error_message = "Each source_identities item must match ^[a-z][a-z0-9-]{1,31}$."
  }
}

variable "post_back" {
  description = "Send the one-time post-back to the Multicloud API after the role exists. The default, true, is right for a customer. Set false only if Multicloud tells you to connect the account another way."
  type        = bool
  default     = true
}
