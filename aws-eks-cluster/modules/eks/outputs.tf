output "cluster-name" {
  value = aws_eks_cluster.cluster.name
}

output "oidc-arn" {
  value = aws_iam_openid_connect_provider.cluster.arn
}

output "oidc-id" {
  value = local.oidc-id
}

output "cluster-security-group-id" {
  value = aws_eks_cluster.cluster.vpc_config[0].cluster_security_group_id
}