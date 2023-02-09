output "role-arn" {
  value = aws_iam_role.instance-role.arn
}

output "security-group-id" {
  value = aws_security_group.instance-sg.id
}