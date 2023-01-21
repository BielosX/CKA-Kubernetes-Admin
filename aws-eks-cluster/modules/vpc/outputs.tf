output "private-subnet-ids" {
  value = aws_subnet.private-subnet[*].id
}

output "public-subnet-ids" {
  value = aws_subnet.pubic-subnet[*].id
}