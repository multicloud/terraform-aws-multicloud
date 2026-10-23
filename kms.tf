# Optional permissions for EBS volumes that a customer-managed KMS key encrypts (R12).
# Without them, an account that encrypts EBS by default with its own key fails every launch.
# The statements name only the keys in var.ebs_kms_key_arns and only calls that EC2 makes
# on your behalf. When the list is empty, the role gets no KMS permission.

locals {
  ebs_kms_statements = length(var.ebs_kms_key_arns) == 0 ? [] : [
    {
      Sid    = "EbsCustomerKeyUse"
      Effect = "Allow"
      Action = [
        "kms:Decrypt",
        "kms:DescribeKey",
        "kms:GenerateDataKeyWithoutPlaintext",
        "kms:ReEncryptFrom",
        "kms:ReEncryptTo",
      ]
      Resource  = var.ebs_kms_key_arns
      Condition = { StringLike = { "kms:ViaService" = "ec2.*.amazonaws.com" } }
    },
    {
      Sid      = "EbsCustomerKeyGrant"
      Effect   = "Allow"
      Action   = ["kms:CreateGrant"]
      Resource = var.ebs_kms_key_arns
      Condition = {
        StringLike = { "kms:ViaService" = "ec2.*.amazonaws.com" }
        Bool       = { "kms:GrantIsForAWSResource" = "true" }
      }
    },
  ]
}
