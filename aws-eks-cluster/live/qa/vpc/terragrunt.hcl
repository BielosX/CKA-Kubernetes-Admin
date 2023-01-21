include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules//vpc"
}

locals {
  common-vars = yamldecode(file(find_in_parent_folders("common_vars.yaml")))
  cluster-name = local.common-vars.cluster-name
}

inputs = {
  cidr = "10.0.0.0/16"
  public-subnets-tags = {
    "kubernetes.io/cluster/${local.cluster-name}": "shared"
  }
  private-subnets-tags = {
    "kubernetes.io/cluster/${local.cluster-name}": "shared"
  }
  public-subnets = 2
  private-subnets = 2
  name = "eks-cluster-vpc"
  subnet-size = 256
}