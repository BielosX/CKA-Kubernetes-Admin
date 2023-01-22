include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules//ebs"
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  name = "eks-persistent-volume"
  availability-zone = dependency.vpc.outputs.private-subnets-azs[0]
}