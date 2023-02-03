resource "aws_security_group" "bind-sg" {
  vpc_id = var.vpc-id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 53
    to_port = 53
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "udp"
    from_port = 53
    to_port = 53
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 443
    to_port = 443
  }
}

resource "aws_ssm_parameter" "cloudwatch-agent-config" {
  name = "bind-dns-cw-agent-config"
  type = "String"
  value = file("${path.module}/amazon-cloudwatch-agent.json")
}

module "amzn_linux2_instance" {
  source = "git::https://github.com/BielosX/AWS-SysOps.git//amzn_linux2_instance"
  instance-type = "t3.micro"
  name = "bind-dns"
  security-group-ids = [aws_security_group.bind-sg.id]
  subnet-id = var.subnet-id
  user-data = templatefile("${path.module}/init.sh", {
    cw_config_param: aws_ssm_parameter.cloudwatch-agent-config.id
  })
}

resource "aws_codedeploy_app" "bind-dns-app" {
  name = "bind-dns"
  compute_platform = "Server"
}

resource "aws_codedeploy_deployment_config" "bind-dns-deployment-config" {
  deployment_config_name = "bind-dns-deployment-config"
  minimum_healthy_hosts {
    type = "HOST_COUNT"
    value = 0
  }
}

data "aws_iam_policy_document" "code-deploy-assume-role" {
  version = "2012-10-17"
  statement {
    effect = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      identifiers = ["codedeploy.amazonaws.com"]
      type        = "Service"
    }
  }
}

resource "aws_iam_role" "code-deploy-service-role" {
  assume_role_policy = data.aws_iam_policy_document.code-deploy-assume-role.json
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  ]
}

resource "aws_codedeploy_deployment_group" "bind-dns-deployment-group" {
  app_name = aws_codedeploy_app.bind-dns-app.name
  deployment_group_name = "bind-dns-deployment-group"
  service_role_arn = aws_iam_role.code-deploy-service-role.arn
  deployment_config_name = aws_codedeploy_deployment_config.bind-dns-deployment-config.id

  ec2_tag_set {
    ec2_tag_filter {
      key = "Name"
      type = "KEY_AND_VALUE"
      value = "bind-dns"
    }
  }
}