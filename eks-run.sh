#!/bin/bash

BACKEND_STACK="terraform-backend"
export AWS_DEFAULT_REGION="eu-west-1"
export AWS_REGION="eu-west-1"
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
export AWS_PAGER=""

function kubeconfig() {
  rm ~/.kube/config
  aws eks update-kubeconfig --region "$AWS_REGION" --name eks-demo-cluster
}

function create_fluent_bit_config_map() {
  pushd aws-eks-cluster/fluent-bit || exit
  kubectl create configmap fluent-bit-config \
    -n amazon-cloudwatch \
    --from-file=parsers.conf \
    --from-file=host-log.conf \
    --from-file=fluent-bit.conf \
    --from-file=dataplane-log.conf \
    --from-file=application-log.conf \
    --dry-run=client -o yaml | kubectl apply -f -
  kubectl label configmaps -n amazon-cloudwatch fluent-bit-config k8s-app=fluent-bit
  popd || exit
}

function deploy() {
  pushd aws-eks-cluster/live || exit
  aws cloudformation deploy --template-file terraform_backend.yaml --stack-name "$BACKEND_STACK"
  terragrunt run-all apply --terragrunt-working-dir qa --terragrunt-non-interactive || exit
  kubeconfig
  role_arn="arn:aws:iam::${ACCOUNT_ID}:role/eks-demo-cluster-AmazonEKS_EBS_CSI_DriverRole"
  aws eks create-addon --cluster-name "eks-demo-cluster" --addon-name aws-ebs-csi-driver \
    --service-account-role-arn "$role_arn"
  popd || exit
  export CLUSTER_NAME="eks-demo-cluster"
  export CW_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/eks-demo-cluster-cloudwatch-agent-role"
  kubectl apply -f aws-eks-cluster/cloudwatch-namespace.yaml
  envsubst < aws-eks-cluster/cloudwatch-agent.yaml | kubectl apply -f -

  create_fluent_bit_config_map
  export FLUENT_BIT_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/eks-demo-cluster-fluent-bit-role"
  pushd aws-eks-cluster/fluent-bit || exit
  envsubst < service-account.yaml | kubectl apply -f -
  envsubst < config-map.yaml | kubectl apply -f -
  kubectl apply -f fluent-bit.yaml
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

function create_static_persistent_volume() {
  pushd static-persistent-volume || exit
  volume=$(aws ec2 describe-volumes --filters 'Name=tag:Name,Values=eks-persistent-volume' | jq -r '.Volumes[0]')
  volume_id=$(jq -r '.VolumeId' <<< "$volume")
  volume_az=$(jq -r '.AvailabilityZone' <<< "$volume")
  sed -e "s/{volume_id}/${volume_id}/g" \
    -e "s/{availability_zone}/${volume_az}/g" \
    persistent-volume.yaml | kubectl apply -f -
  kubectl apply -f db.yaml
  popd || exit
}

function delete_static_persistent_volume() {
  pushd static-persistent-volume || exit
  kubectl delete -f db.yaml
  kubectl delete persistentvolume ebs-persistent-volume
  popd || exit
}

function create_dynamic_persistent_volume() {
  pushd dynamic-persistent-volume || exit
  class_name="slow-ebs"
  iops="3500"
  throughput="200"
  sed -e "s/{class_name}/${class_name}/g" \
    -e "s/{iops}/${iops}/g" \
    -e "s/{throughput}/${throughput}/g" \
    storage-class.yaml | kubectl apply -f -
  sed -e "s/{storage_class}/${class_name}/g" \
    db.yaml | kubectl apply -f -
  popd || exit
}

function delete_dynamic_persistent_volume() {
  pushd dynamic-persistent-volume || exit
  kubectl delete -f db.yaml
  kubectl delete storageclass slow-ebs
  popd || exit
}

function deploy_affinity_single_aws_az() {
  node_group=$(aws eks list-nodegroups --cluster-name eks-demo-cluster \
    | jq -r '.nodegroups[0]')
  subnet=$(aws eks describe-nodegroup  --cluster-name eks-demo-cluster --nodegroup-name "$node_group" \
    | jq -r '.nodegroup.subnets[0]')
  az=$(aws ec2 describe-subnets --subnet-ids "$subnet" | jq -r '.Subnets[0].AvailabilityZone')
  export AWS_AZ="$az"
  kubectl apply -f affinity-single-aws-az/config-map.yaml
  envsubst < affinity-single-aws-az/nginx.yaml | kubectl apply -f -
}

function delete_affinity_single_aws_az() {
  kubectl delete -f affinity-single-aws-az/nginx.yaml
  kubectl delete -f affinity-single-aws-az/config-map.yaml
}

case "$1" in
  "deploy") deploy ;;
  "destroy") destroy ;;
  "kubeconfig") kubeconfig ;;
  "create-static-persistent-volume") create_static_persistent_volume ;;
  "delete-static-persistent-volume") delete_static_persistent_volume ;;
  "create-dynamic-persistent-volume") create_dynamic_persistent_volume ;;
  "delete-dynamic-persistent-volume") delete_dynamic_persistent_volume ;;
  "deploy-affinity-single-aws-az") deploy_affinity_single_aws_az ;;
  "delete-affinity-single-aws-az") delete_affinity_single_aws_az ;;
esac