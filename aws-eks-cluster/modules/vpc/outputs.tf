output "private-subnet-ids" {
  value = aws_subnet.private-subnet[*].id
}

output "public-subnet-ids" {
  value = aws_subnet.pubic-subnet[*].id
}

output "private-subnets-azs" {
  value = aws_subnet.private-subnet[*].availability_zone
}

output "public-subnets-azs" {
  value = aws_subnet.pubic-subnet[*].availability_zone
}
