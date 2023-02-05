resource "aws_security_group" "security-group" {
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
    from_port = 443
    to_port = 443
  }
  egress {
    cidr_blocks = ["0.0.0.0/0"]
    protocol = "tcp"
    from_port = 80
    to_port = 80
  }
}

module "amzn_linux2_instance" {
  source = "git::https://github.com/BielosX/AWS-SysOps.git//amzn_linux2_instance"
  instance-type = "t3.micro"
  name = "nginx-server"
  security-group-ids = [aws_security_group.security-group.id]
  subnet-id = var.subnet-id
  user-data = file("${path.module}/init.sh")
  private-ip = var.private-ip
  eip = false
}
