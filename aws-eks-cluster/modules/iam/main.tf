data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
}

data "aws_iam_policy_document" "ebs-driver-assume-role" {
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
      variable = "oidc.eks.${local.region}.amazonaws.com/id/${var.oidc-id}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test = "StringEquals"
      values = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
      variable = "oidc.eks.${local.region}.amazonaws.com/id/${var.oidc-id}:sub"
    }
  }
}

resource "aws_iam_role" "ebs-driver-role" {
  name = "${var.cluster-name}-AmazonEKS_EBS_CSI_DriverRole"
  assume_role_policy = data.aws_iam_policy_document.ebs-driver-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
}