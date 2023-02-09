resource "aws_security_group_rule" "api-server-inbound" {
  type = "ingress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  source_security_group_id = var.self-managed-nodes-security-group-id
  security_group_id = var.cluster-security-group-id
}

resource "aws_security_group_rule" "control-plane-outbound" {
  type = "egress"
  protocol = "tcp"
  from_port = 1025
  to_port = 65535
  source_security_group_id = var.self-managed-nodes-security-group-id
  security_group_id = var.cluster-security-group-id
}

resource "aws_security_group_rule" "control-plane-extension-api-server-outbound" {
  description = "Allow control plane to communicate with extension api server"
  type = "egress"
  protocol = "tcp"
  from_port = 443
  to_port = 443
  source_security_group_id = var.self-managed-nodes-security-group-id
  security_group_id = var.cluster-security-group-id
}