#!/bin/bash

yum -y update
yum -y install httpd
yum -y install jq

TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/placement/availability-zone)
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)

cat <<EOT >> /var/www/html/index.html
<h1>Hello from EC2!</h1>
<p>InstanceId: ${INSTANCE_ID}</p>
<p>AvailabilityZone: ${AZ}</p>
EOT

systemctl enable httpd
systemctl start httpd