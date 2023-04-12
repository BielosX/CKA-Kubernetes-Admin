resource "aws_security_group" "lb-security-group" {
  vpc_id = var.vpc-id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 80
    to_port = 80
  }
  egress {
    security_groups = [var.cluster-sg]
    protocol = "tcp"
    from_port = 1024
    to_port = 65535
  }
}

resource "aws_lb" "load-balancer" {
  name = "${var.cluster-name}-load-balancer"
  load_balancer_type = "application"
  security_groups = [aws_security_group.lb-security-group.id]
  subnets = var.lb-subnets
  tags = {
    "kubernetes.io/cluster/${var.cluster-name}": "owned"
  }
}

resource "aws_alb_target_group" "target-group" {
  name = "${var.cluster-name}-demo-target"
  target_type = "ip"
  port = 8080
  protocol = "HTTP"
  vpc_id = var.vpc-id
  tags = {
    "kubernetes.io/cluster/${var.cluster-name}": "owned"
  }
}

resource "aws_alb_listener" "listener" {
  load_balancer_arn = aws_lb.load-balancer.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_alb_target_group.target-group.arn
  }
}