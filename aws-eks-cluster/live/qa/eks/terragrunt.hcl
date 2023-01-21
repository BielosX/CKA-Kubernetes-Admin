include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules//eks"
}

locals {
  common-vars = yamldecode(file(find_in_parent_folders("common_vars.yaml")))
  cluster-name = local.common-vars.cluster-name
}

dependency "vpc" {
  config_path = "../vpc"
}

inputs = {
  cluster-name = local.cluster-name
  subnet-ids = dependency.vpc.outputs.private-subnet-ids
  min-size = 2
  max-size = 4
}
