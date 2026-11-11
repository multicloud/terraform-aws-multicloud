variable "name" {
  description = "The display name of the new AWS account, for example multicloud-acme-42."
  type        = string

  validation {
    condition     = length(var.name) >= 1 && length(var.name) <= 50
    error_message = "name must have 1 to 50 characters."
  }
}

variable "email" {
  description = "The email address of the new AWS account. No other AWS account may use it."
  type        = string

  validation {
    condition     = can(regex("^[^@[:space:]]+@[^@[:space:]]+\\.[^@[:space:]]+$", var.email))
    error_message = "email must be an email address."
  }
}

variable "parent_id" {
  description = "Optional. The ID of the AWS Organizations root or organizational unit that gets the new account. Default: the root."
  type        = string
  default     = null
}
