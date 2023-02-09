#!/bin/bash

BACKEND_STACK="terraform-backend"
export AWS_DEFAULT_REGION="eu-west-1"
export AWS_REGION="eu-west-1"
ACCOUNT_ID=$(aws sts get-caller-identity | jq -r '.Account')
export AWS_PAGER=""

function install_nginx_controller() {
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  helm upgrade -i ingress-nginx ingress-nginx/ingress-nginx \
    --namespace kube-system \
    --set controller.service.type=LoadBalancer \
    --set clusterName="eks-demo-cluster" \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller \
    --set controller.service.annotations."service\.beta\.kubernetes\.io/aws-load-balancer-type"="nlb" \
    --set controller.ingressClassResource.default=true
}

function remove_terraform_cache() {
  find . -type d -name '.terraform' -prune -exec rm -rf {} \;
}

function get_all_k8s_managed_alb() {
 alb=$(kubectl get ingress --all-namespaces -o json \
  | jq -r '.items | map(.status.loadBalancer.ingress) | flatten | map(.hostname)')
}

function wait_for_alb_destroy() {
  albDnsToArn=$(aws elbv2 describe-load-balancers \
    | jq -r '.LoadBalancers | map ( { (.DNSName): (.LoadBalancerArn) } ) | add')
  len=$(jq -r 'length' <<< "$1")
  counter=0
  while (( counter < len )); do
    for ((i=0;i<len;i++)); do
      alb_hostname=$(jq -r ".[$i]" <<< "$1")
      alb_arn=$(jq -r ".[\"${alb_hostname}\"]" <<< "$albDnsToArn")
      if [ "$alb_arn" != "" ]; then
        if aws elbv2 describe-load-balancers --load-balancer-arns "$alb_arn" > /dev/null 2>&1 ; then
          echo "ALB ${alb_hostname} still exists. Waiting"
        else
          echo "ALB ${alb_hostname} removed."
          counter=$((counter+1))
        fi
      fi
    done
    sleep 10
  done
}

function create_bind_dns_package() {
  pushd aws-eks-cluster/modules/bind-dns || exit
  rm -f package.zip
  zip package.zip appspec.yml
  zip -r9 package.zip configs
  zip -r9 package.zip scripts
  popd || exit
}

function deploy_bind_dns_config() {
  create_bind_dns_package

  bucket_name="bind-dns-config-${AWS_REGION}-${ACCOUNT_ID}"
  timestamp=$(date +%s)
  file_name="app-${timestamp}.zip"

  pushd aws-eks-cluster/modules/bind-dns || exit
  aws s3 cp package.zip "s3://${bucket_name}/${file_name}"
  popd || exit

read -r -d '' revision << EOM
{
  "revisionType": "S3",
  "s3Location": {
    "bucket": "${bucket_name}",
    "key": "${file_name}",
    "bundleType": "zip"
  }
}
EOM

  aws deploy create-deployment \
    --application-name "bind-dns" \
    --deployment-group-name "bind-dns-deployment-group" \
    --revision "$revision"

}

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

function create_aws_load_balancer_controller_sa() {
  export ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/eks-demo-cluster-load-balancer-controller-role"
  envsubst < aws-eks-cluster/aws-load-balancer-controller.yaml | kubectl apply -f -
}

function install_alb_controller() {
  helm repo add eks https://aws.github.io/eks-charts
  helm repo update
  helm upgrade -i aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName="eks-demo-cluster" \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-load-balancer-controller
}

function delete_all_k8s_resources() {
  namespaces=$(kubectl get namespaces -o json | jq -r '.items | map(.metadata.name) | .[]')
  while IFS= read -r namespace; do
    if [[ "$namespace" =~ ^kube.* ]]; then
      echo "Skipping namespace ${namespace}"
    else
      echo "Deleting all resources in ${namespace}"
      kubectl delete all --all -n "$namespace"
    fi
  done <<< "$namespaces"
  # For some reason 'kubectl delete all' doesn't touch ingress (at least these with AWS ALB)
  # It needs to be removed separately
  ingress=$(kubectl get ingress --all-namespaces -o json \
    | jq -r '.items | map({ "name": (.metadata.name), namespace: (.metadata.namespace) })')
  ingress_len=$(jq -r 'length' <<< "$ingress")
  for ((i=0;i<ingress_len;i++)); do
    ingress_item=$(jq -r ".[$i]" <<< "$ingress")
    ingress_name=$(jq -r '.name' <<< "$ingress_item")
    ingress_namespace=$(jq -r '.namespace' <<< "$ingress_item")
    echo "Deleting ${ingress_name} from namespace ${ingress_namespace}"
    kubectl delete ingress "$ingress_name" -n "$ingress_namespace"
  done
}

function deploy() {
  remove_terraform_cache

  pushd aws-eks-cluster/live || exit
  aws cloudformation deploy --template-file terraform_backend.yaml --stack-name "$BACKEND_STACK"
  bucket_name="eks-cluster-${AWS_REGION}-${ACCOUNT_ID}"

  pushd qa || exit
  terraform init \
    -backend-config="bucket=${bucket_name}" || exit
  terraform apply -auto-approve || exit
  popd || exit

  kubeconfig
  role_arn="arn:aws:iam::${ACCOUNT_ID}:role/eks-demo-cluster-AmazonEKS_EBS_CSI_DriverRole"
  aws eks create-addon --cluster-name "eks-demo-cluster" --addon-name aws-ebs-csi-driver \
    --service-account-role-arn "$role_arn"
  popd || exit

  self_managed_node_role_arn="arn:aws:iam::${ACCOUNT_ID}:role/eks-demo-cluster-self-managed-node-role"
  export ROLE_ARN="$self_managed_node_role_arn"
  envsubst < aws-eks-cluster/aws-auth-cm.yaml | kubectl apply -f -

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

  create_aws_load_balancer_controller_sa
  install_alb_controller
  install_nginx_controller

read -r -d '' refresh_config << EOM
{
  "MinHealthyPercentage": 0
}
EOM

  aws autoscaling start-instance-refresh \
    --auto-scaling-group-name "self-managed-nodes" \
    --strategy "Rolling" \
    --preferences "$refresh_config"
}

function destroy() {
  get_all_k8s_managed_alb
  helm uninstall ingress-nginx -n kube-system
  delete_all_k8s_resources
  wait_for_alb_destroy "$alb"

  pushd aws-eks-cluster/live/qa || exit
  terraform destroy -auto-approve || exit
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

function deploy_aws_az_spread() {
  pushd aws-az-spread || exit
  kubectl apply -f config-map.yaml
  kubectl apply -f nginx.yaml
  popd || exit
}

function delete_aws_az_spread() {
  pushd aws-az-spread || exit
  kubectl delete -f nginx.yaml
  kubectl delete -f config-map.yaml
  popd || exit
}

function create_pod_dns() {
  pushd pod-dns || exit
  hosted_zone_id=$(aws route53 list-hosted-zones-by-name --dns-name "bielosx.example.com" \
    | jq -r '.HostedZones[0].Id')
  dns_addr=$(aws route53 list-resource-record-sets --hosted-zone-id "$hosted_zone_id" \
    | jq -r '.ResourceRecordSets[] | select(.Type == "NS") | .ResourceRecords[0].Value')
  dns_ip=$(dig +short "$dns_addr" | tail -n1)
  kubectl apply -f nginx-config-map.yaml
  export ROUTE_53_DNS="$dns_ip"
  envsubst < config.yaml | kubectl apply -f -
  popd || exit
}

function delete_pod_dns() {
  pushd pod-dns || exit
  kubectl delete -f config.yaml
  kubectl delete -f nginx-config-map.yaml
  popd || exit
}

function deploy_aws_nginx_controller_ingress() {
  pushd aws-nginx-controller-ingress || exit
  config_map="hello-scripts"
  kubectl create configmap "$config_map" \
    --from-file=main.py \
    --from-file=requirements.txt \
    --dry-run=client -o yaml | kubectl apply -f -
  export CONFIG_MAP_NAME="$config_map"
  envsubst < config.yaml | kubectl apply -f -
  popd || exit
}

function delete_aws_nginx_controller_ingress() {
  pushd aws-nginx-controller-ingress || exit
  kubectl delete -f config.yaml
  kubectl delete configmap hello-scripts
  popd || exit
}

case "$1" in
  "bind-dns-package") create_bind_dns_package ;;
  "deploy-bind-dns-config") deploy_bind_dns_config ;;
  "delete-all-k8s-resources") delete_all_k8s_resources ;;
  "deploy") deploy ;;
  "destroy") destroy ;;
  "kubeconfig") kubeconfig ;;
  "create-static-persistent-volume") create_static_persistent_volume ;;
  "delete-static-persistent-volume") delete_static_persistent_volume ;;
  "create-dynamic-persistent-volume") create_dynamic_persistent_volume ;;
  "delete-dynamic-persistent-volume") delete_dynamic_persistent_volume ;;
  "deploy-affinity-single-aws-az") deploy_affinity_single_aws_az ;;
  "delete-affinity-single-aws-az") delete_affinity_single_aws_az ;;
  "deploy-aws-az-spread") deploy_aws_az_spread ;;
  "delete-aws-az-spread") delete_aws_az_spread ;;
  "create-pod-dns") create_pod_dns ;;
  "delete-pod-dns") delete_pod_dns ;;
  "deploy-aws-nginx-controller-ingress") deploy_aws_nginx_controller_ingress ;;
  "delete-aws-nginx-controller-ingress") delete_aws_nginx_controller_ingress ;;
esac