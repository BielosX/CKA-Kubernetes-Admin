module "ebs-driver-assume-role" {
  source = "../sa-assume-role-policy"
  namespace = "kube-system"
  service-account = "ebs-csi-controller-sa"
  oidc-arn = var.oidc-arn
  oidc-id = var.oidc-id
}

resource "aws_iam_role" "ebs-driver-role" {
  name = "${var.cluster-name}-AmazonEKS_EBS_CSI_DriverRole"
  assume_role_policy = module.ebs-driver-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"]
}

module "cloudwatch-agent-assume-role" {
  source = "../sa-assume-role-policy"
  namespace = "amazon-cloudwatch"
  service-account = "cloudwatch-agent"
  oidc-arn = var.oidc-arn
  oidc-id = var.oidc-id
}

resource "aws_iam_role" "cloudwatch-agent-role" {
  name = "${var.cluster-name}-cloudwatch-agent-role"
  assume_role_policy = module.cloudwatch-agent-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"]
}

module "fluent-bit-assume-role" {
  source = "../sa-assume-role-policy"
  namespace = "amazon-cloudwatch"
  service-account = "fluent-bit"
  oidc-arn = var.oidc-arn
  oidc-id = var.oidc-id
}

resource "aws_iam_role" "fluent-bit-role" {
  name = "${var.cluster-name}-fluent-bit-role"
  assume_role_policy = module.fluent-bit-assume-role.json
  managed_policy_arns = ["arn:aws:iam::aws:policy/CloudWatchFullAccess"]
}

module "alb-controller-assume-role" {
  source = "../sa-assume-role-policy"
  namespace = "kube-system"
  service-account = "aws-load-balancer-controller"
  oidc-arn = var.oidc-arn
  oidc-id = var.oidc-id
}

resource "aws_iam_role" "load-balancer-controller-role" {
  assume_role_policy = module.alb-controller-assume-role.json
  name = "${var.cluster-name}-load-balancer-controller-role"
  inline_policy {
    name = "alb-controller-policy"
    policy = file("${path.module}/load_balancer_controller_iam_policy.json")
  }
}
