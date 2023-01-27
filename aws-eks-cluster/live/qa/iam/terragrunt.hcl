include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules//iam"
}

dependency "eks" {
  config_path = "../eks"
}

inputs = {
  cluster-name = dependency.eks.outputs.cluster-name
  oidc-id = dependency.eks.outputs.oidc-id
  oidc-arn = dependency.eks.outputs.oidc-arn
}
