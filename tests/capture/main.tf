terraform {
  required_version = ">= 1.5.0"
}

# Test helper: reads the capture file that tests/fake_curl.sh writes and exposes
# what the tests assert on. Not part of the published module.

variable "path" {
  type = string
}

locals {
  lines = fileexists(var.path) ? split("\n", file(var.path)) : []

  bodies = [for l in local.lines : trimprefix(l, "ENV MC_BODY=") if startswith(l, "ENV MC_BODY=")]
  tokens = [for l in local.lines : trimprefix(l, "ENV MC_CONNECT_TOKEN=") if startswith(l, "ENV MC_CONNECT_TOKEN=")]
  stdins = [for l in local.lines : trimprefix(l, "STDIN ") if startswith(l, "STDIN ")]
  urls   = [for l in local.lines : trimprefix(l, "ENV MC_URL=") if startswith(l, "ENV MC_URL=")]
}

output "calls" {
  value = length([for l in local.lines : l if l == "CALL"])
}

# Every ARGV line of every call, joined: the tests assert the token is absent.
output "argv" {
  value = join("\n", [for l in local.lines : l if startswith(l, "ARGV ")])
}

output "last_token" {
  value = length(local.tokens) == 0 ? "" : local.tokens[length(local.tokens) - 1]
}

output "last_url" {
  value = length(local.urls) == 0 ? "" : local.urls[length(local.urls) - 1]
}

output "last_body" {
  value = length(local.bodies) == 0 ? {} : jsondecode(local.bodies[length(local.bodies) - 1])
}

output "last_stdin" {
  value = length(local.stdins) == 0 ? "" : local.stdins[length(local.stdins) - 1]
}
