#!/bin/bash
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
  yum -y install jq
  yum -y install wget

  TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
  document=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/dynamic/instance-identity/document)
  REGION=$(jq -r '.region' <<< "$document")

  CW_AGENT="https://s3.$REGION.amazonaws.com/amazoncloudwatch-agent-$REGION/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm"

  wget -nv "$CW_AGENT"
  rpm -U ./amazon-cloudwatch-agent.rpm

  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:${cw_config_param}

  extra_args=""
  if [[ "${labels}" != "" ]]; then
    extra_args+=" --node-labels ${labels}"
  fi
  if [[ "${taints}" != "" ]]; then
    extra_args+=" --register-with-taints ${taints}"
  fi
  if [ "$extra_args" == "" ]; then
    /etc/eks/bootstrap.sh "${cluster_name}" \
      --container-runtime containerd
  else
    /etc/eks/bootstrap.sh "${cluster_name}" \
      --container-runtime containerd \
      --kubelet-extra-args "$extra_args"
  fi
