# Provider pins for the account submodule. Same constraints as the connect module (../../versions.tf).
# No provider block here: the caller configures the aws provider with management account credentials.

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.15.0"
    }
  }
}
