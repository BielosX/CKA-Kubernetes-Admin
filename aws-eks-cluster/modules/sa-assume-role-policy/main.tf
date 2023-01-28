data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
  oidc-provider = "oidc.eks.${local.region}.amazonaws.com/id/${var.oidc-id}"
}

data "aws_iam_policy_document" "sa-assume-role-policy" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    principals {
      identifiers = [var.oidc-arn]
      type = "Federated"
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test = "StringEquals"
      variable = "${local.oidc-provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test = "StringEquals"
      values = ["system:serviceaccount:${var.namespace}:${var.service-account}"]
      variable = "${local.oidc-provider}:sub"
    }
  }
}