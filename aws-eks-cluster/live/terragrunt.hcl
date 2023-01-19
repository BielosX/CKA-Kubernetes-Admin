locals {
  region = get_env("AWS_REGION", "eu-west-1")
}

generate "backend" {
  path = "backend.tf"
  if_exists = "overwrite_terragrunt"
  contents = <<-EOF
  terraform {
    backend "s3" {
      bucket = "eks-cluster-${local.region}-${get_aws_account_id()}"
      key = "${path_relative_to_include()}/terraform.tfstate"
      region = "${local.region}"
      encrypt = true
      dynamodb_table = "eks-cluster-lock"
    }
  }
  EOF
}