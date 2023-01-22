resource "aws_ebs_volume" "volume" {
  availability_zone = var.availability-zone
  type = "gp3"
  iops = 3000
  size = 20
  tags = {
    Name: var.name
  }
}