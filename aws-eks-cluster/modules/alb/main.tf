resource "aws_security_group" "lb-security-group" {
  vpc_id = var.vpc-id
  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 80
    to_port = 80
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
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
  target_type = "instance"
  port = 8080
  protocol = "HTTP"
  vpc_id = var.vpc-id
  health_check {
    matcher = "200-299"
    path = "/"
    protocol = "HTTP"
  }
  tags = {
    "kubernetes.io/cluster/${var.cluster-name}": "owned"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_alb_listener" "listener" {
  load_balancer_arn = aws_lb.load-balancer.arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      status_code = "HTTP_301"
      path = "/"
    }
  }
}

resource "aws_lb_listener_rule" "forward-rule" {
  listener_arn = aws_alb_listener.listener.arn

  action {
    type = "forward"
    target_group_arn = aws_alb_target_group.target-group.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}