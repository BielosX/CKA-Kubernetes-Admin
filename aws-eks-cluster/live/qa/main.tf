provider "aws" {
  region = "eu-west-1"
}

terraform {
  backend "s3" {
    key = "terraform.tfstate"
    region = "eu-west-1"
    encrypt = true
    dynamodb_table = "eks-cluster-lock"
  }
}

module "infra" {
  source = "../../"
  cluster-name = "eks-demo-cluster"
}