#!/bin/bash

apt-get install apt-transport-https awscli jq

AWS_REGION="eu-west-1"

mkdir -p $HOME/.aws
cat > $HOME/.aws/config <<EOF
[default]
region=${AWS_REGION}

EOF

# Set this to the AutoScalingGroup of backends for Varnish
#BACKEND_LAYER="ApacheLayer"
# Either that or you could attach certain tagname with this value to the SecurityGroup|AutoScalingGroup and retrieve it here with aws cli.
# Something similar to:
BACKEND_LAYER="$(aws ec2 describe-tags  --filters "Name=resource-id,Values=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" "Name=key,Values=backend-layer" | jq -r ".Tags[0].Value")"


curl https://repo.varnish-cache.org/GPG-key.txt | apt-key add -
echo "deb https://repo.varnish-cache.org/ubuntu/ precise varnish-4.0" >> /etc/apt/sources.list.d/varnish-cache.list
apt-get update
apt-get -y install varnish 

curl -o /etc/varnish/autoscalinggroup.vcl https://github.com/jnerin/varnish-4-aws-ec2-autoscalinggroup/raw/master/varnish/autoscalinggroup.vcl

# Change the varnish boot vcl
sed -ri.orig -e 's/^([^#].*-f \/etc\/varnish\/).*\.vcl/\1autoscalinggroup.vcl/' /etc/defaults/varnish


echo "${BACKEND_LAYER}" >/etc/varnish/backend-layer

#curl -o /etc/varnish/generate-backends.sh 
#chmod 750 /etc/varnish/generate-backends.sh 


