terraform {
  required_version = ">= 1.5.0"
}

# Test helper: deletes the capture file, so each `tofu test` run starts from zero calls.
# Not part of the published module.

variable "path" {
  type = string
}

resource "terraform_data" "reset" {
  provisioner "local-exec" {
    command     = "rm -f \"$CAPTURE_PATH\""
    environment = { CAPTURE_PATH = var.path }
  }
}
