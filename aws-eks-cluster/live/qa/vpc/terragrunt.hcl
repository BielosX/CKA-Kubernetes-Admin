include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "../../..//vpc"
}

inputs = {
  cidr = "10.0.0.0/16"
}