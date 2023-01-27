data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
  oidc-provider = "oidc.eks.${local.region}.amazonaws.com/id/${var.oidc-id}"
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
      variable = "${local.oidc-provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test = "StringEquals"
      values = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
      variable = "${local.oidc-provider}:sub"
    }
  }
}

resource "aws_iam_role" "ebs-driver-role" {
  name = "${var.cluster-name}-AmazonEKS_EBS_CSI_DriverRole"
  assume_role_policy = data.aws_iam_policy_document.ebs-driver-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
}

data "aws_iam_policy_document" "cloud-watch-agent-assume-role" {
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
      values = ["system:serviceaccount:amazon-cloudwatch:cloudwatch-agent"]
      variable = "${local.oidc-provider}:sub"
    }
  }
}

resource "aws_iam_role" "cloudwatch-agent-role" {
  name = "${var.cluster-name}-cloudwatch-agent-role"
  assume_role_policy = data.aws_iam_policy_document.cloud-watch-agent-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
}
