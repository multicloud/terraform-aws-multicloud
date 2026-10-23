# Provider pins for the customer AWS connect module.
#
# - Exact provider version, same pin as the bootstrap aws-env module.
# - required_version floor 1.5.0 works for both Terraform (BUSL) and OpenTofu.
# - No provider block here: the caller configures the aws provider (region, profile).
#   A module with its own provider block cannot be removed with `terraform destroy`
#   once the caller drops it.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.15.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
  }
}
