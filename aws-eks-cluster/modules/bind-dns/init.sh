#!/bin/bash

yum -y install bind bind-utils

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
document=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/dynamic/instance-identity/document)
REGION=$(jq -r '.region' <<< "$document")

CW_AGENT="https://s3.$REGION.amazonaws.com/amazoncloudwatch-agent-$REGION/amazon_linux/amd64/latest/amazon-cloudwatch-agent.rpm"

wget -nv "$CW_AGENT"
rpm -U ./amazon-cloudwatch-agent.rpm

CODE_DEPLOY_URL="https://aws-codedeploy-$REGION.s3.$REGION.amazonaws.com/latest/install"
wget "$CODE_DEPLOY_URL"
chmod +x ./install
./install auto

systemctl enable named

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:${cw_config_param}