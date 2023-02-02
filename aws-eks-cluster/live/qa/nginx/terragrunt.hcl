include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../../modules//nginx"
}

dependency "vpc" {
  config_path = "../vpc"
  mock_outputs = {
    private-subnet-ids = []
  }
}

inputs = {
  vpc-id = dependency.vpc.outputs.vpc-id
  subnet-id = dependency.vpc.outputs.private-subnet-ids[0]
}