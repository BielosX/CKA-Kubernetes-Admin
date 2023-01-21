#!/bin/bash

BACKEND_STACK="terraform-backend"
export AWS_DEFAULT_REGION="eu-west-1"
export AWS_REGION="eu-west-1"

function deploy() {
  pushd aws-eks-cluster/live || exit
  aws cloudformation deploy --template-file terraform_backend.yaml --stack-name "$BACKEND_STACK"
  terragrunt run-all apply --terragrunt-working-dir qa --terragrunt-non-interactive
  popd || exit
}

function destroy() {
  pushd aws-eks-cluster/live || exit
  terragrunt run-all destroy --terragrunt-working-dir qa --terragrunt-non-interactive || exit
  BUCKET_NAME=$(aws cloudformation describe-stacks --stack-name "$BACKEND_STACK" | jq -r '.Stacks[0].Outputs[0].OutputValue')
  aws s3 rm --recursive "s3://$BUCKET_NAME"
  aws cloudformation delete-stack --stack-name "$BACKEND_STACK"
  aws cloudformation wait stack-delete-complete --stack-name "$BACKEND_STACK"
  popd || exit
}

function kubeconfig() {
  rm ~/.kube/config
  aws eks update-kubeconfig --region "$AWS_REGION" --name eks-demo-cluster
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "kubeconfig") kubeconfig ;;
esac