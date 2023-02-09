data "aws_ssm_parameter" "image-id" {
  name = "/aws/service/eks/optimized-ami/${var.kubernetes-version}/amazon-linux-2/recommended/image_id"
}

data "aws_iam_policy_document" "ec2-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["ec2.amazonaws.com"]
      type        = "Service"
    }
  }
}

locals {
  managed-policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]
}

resource "aws_iam_role" "instance-role" {
  name = "${var.cluster-name}-self-managed-node-role"
  assume_role_policy = data.aws_iam_policy_document.ec2-assume-role.json
}

resource "aws_iam_instance_profile" "instance-profile" {
  role = aws_iam_role.instance-role.id
}

resource "aws_iam_role_policy_attachment" "policy-attachment" {
  for_each = toset(local.managed-policies)
  policy_arn = each.value
  role = aws_iam_role.instance-role.id
}

resource "aws_ssm_parameter" "cloud-watch-agent-config" {
  name = "/${var.name}/cloud-watch-agent-config"
  type = "String"
  value = templatefile("${path.module}/amazon-cloudwatch-agent.json", {
    name: var.name,
    cluster_name: var.cluster-name
  })
}

resource "aws_security_group" "instance-sg" {
  vpc_id = var.vpc-id
  tags = {
    "kubernetes.io/cluster/${var.cluster-name}": "owned"
  }
}

resource "aws_security_group_rule" "node-communication" {
  type = "ingress"
  source_security_group_id = aws_security_group.instance-sg.id
  protocol = "-1"
  from_port = 0
  to_port = 65535
  security_group_id = aws_security_group.instance-sg.id
}

resource "aws_security_group_rule" "https-outbound" {
  description = "Allow node to download packages"
  type = "egress"
  cidr_blocks = ["0.0.0.0/0"]
  protocol = "tcp"
  from_port = 443
  to_port = 443
  security_group_id = aws_security_group.instance-sg.id
}

resource "aws_security_group_rule" "node-inbound" {
  type = "ingress"
  source_security_group_id = var.cluster-security-group-id
  protocol = "tcp"
  from_port = 1025
  to_port = 65535
  security_group_id = aws_security_group.instance-sg.id
}

resource "aws_security_group_rule" "extension-api-server-inbound" {
  type = "ingress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  source_security_group_id = var.cluster-security-group-id
  security_group_id = aws_security_group.instance-sg.id
}

resource "aws_launch_template" "launch-template" {
  image_id = data.aws_ssm_parameter.image-id.value
  instance_type = var.instance-type
  vpc_security_group_ids = [aws_security_group.instance-sg.id]
  user_data = base64encode(templatefile("${path.module}/init.sh", {
    cw_config_param: aws_ssm_parameter.cloud-watch-agent-config.id
    cluster_name: var.cluster-name
  }))
  iam_instance_profile {
    arn = aws_iam_instance_profile.instance-profile.arn
  }
}

resource "aws_autoscaling_group" "node-group" {
  max_size = var.max-size
  min_size = var.min-size
  vpc_zone_identifier = var.subnet-ids

  tag {
    key = "kubernetes.io/cluster/${var.cluster-name}"
    value = "owned"
    propagate_at_launch = true
  }

  tag {
    key = "Name"
    value = var.name
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key = tag.key
      value = tag.value
      propagate_at_launch = false
    }
  }

  launch_template {
    id = aws_launch_template.launch-template.id
    version = aws_launch_template.launch-template.latest_version
  }
}