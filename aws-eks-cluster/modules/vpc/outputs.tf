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

output "vpc-id" {
  value = aws_vpc.vpc.id
}

output "private-subnets-cidrs" {
  value = aws_subnet.private-subnet[*].cidr_block
}

output "public-subnets-cidrs" {
  value = aws_subnet.pubic-subnet[*].cidr_block
}
