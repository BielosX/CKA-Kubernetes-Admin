include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules//ebs"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    private-subnets-azs = []
  }
}

inputs = {
  name = "eks-persistent-volume"
  availability-zone = dependency.vpc.outputs.private-subnets-azs[0]
}