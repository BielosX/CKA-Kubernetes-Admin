data "aws_iam_policy_document" "cluster-role-assume-policy" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["eks.amazonaws.com"]
      type = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "cluster-role" {
  assume_role_policy = data.aws_iam_policy_document.cluster-role-assume-policy.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  ]
}

resource "aws_eks_cluster" "cluster" {
  name = var.cluster-name
  role_arn = aws_iam_role.cluster-role.arn
  vpc_config {
    subnet_ids = var.subnet-ids
  }
}

data "aws_iam_policy_document" "node-role-assume-policy" {
  statement {
    effect = "Allow"
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "node-role" {
  assume_role_policy = data.aws_iam_policy_document.node-role-assume-policy.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  ]
}

resource "aws_eks_node_group" "node-group" {
  cluster_name  = aws_eks_cluster.cluster.name
  node_role_arn = aws_iam_role.node-role.arn
  subnet_ids = var.subnet-ids
  instance_types = var.instance-types

  scaling_config {
    desired_size = var.min-size
    max_size = var.max-size
    min_size = var.min-size
  }

  update_config {
    max_unavailable = 1
  }

  labels = {
    nodeType: "aws-managed"
  }

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}