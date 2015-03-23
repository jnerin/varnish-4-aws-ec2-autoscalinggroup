#!/bin/bash
# The idea is that the user-data of the AutoScalingGroup is something like:
# curl -sL https://raw.githubusercontent.com/jnerin/varnish-4-aws-ec2-autoscalinggroup/master/user-data.sh | bash -s --

APT=$( (lsb_release --id --short |egrep -qi "\b(debian|ubuntu)\b" || apt &>/dev/null ); echo $?)
YUM=$( (lsb_release --id --short |egrep -qi "\b(redhat|fedora|centos)\b" || yum --version >/dev/null); echo $? )

if [ $APT -eq 0 ] ; then
	apt-get install -y apt-transport-https awscli jq
elif [ $YUM -eq 0 ] ; then
	yum install -y aws-cli jq
fi

AWS_REGION="eu-west-1"

mkdir -p /root/.aws
cat > /root/.aws/config <<EOF
[default]
region=${AWS_REGION}

EOF

# Set this to the AutoScalingGroup of backends for Varnish
#BACKEND_LAYER="ApacheLayer"
# Either that or you could attach certain tagname with this value to the SecurityGroup|AutoScalingGroup and retrieve it here with aws cli.
# Something similar to:
BACKEND_LAYER="$(aws ec2 describe-tags  --filters "Name=resource-id,Values=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" "Name=key,Values=backend-layer" | jq -r ".Tags[0].Value")"



if [ $APT -eq 0 ] ; then
	curl https://repo.varnish-cache.org/GPG-key.txt | apt-key add -
	echo "deb https://repo.varnish-cache.org/ubuntu/ precise varnish-4.0" >> /etc/apt/sources.list.d/varnish-cache.list
	apt-get update
	apt-get -y install varnish 
elif [ $YUM -eq 0 ] ; then
	rpm --nosignature -i https://repo.varnish-cache.org/redhat/varnish-4.0.el6.rpm
	echo "priority=10" >>/etc/yum.repos.d/varnish.repo
	yum install -y varnish
fi


curl -o /etc/varnish/autoscalinggroup.vcl https://raw.githubusercontent.com/jnerin/varnish-4-aws-ec2-autoscalinggroup/master/varnish/autoscalinggroup.vcl

# Change the varnish boot vcl
if [ $APT -eq 0 ] ; then
	sed -ri.orig -e 's/^([^#].*-f \/etc\/varnish\/).*\.vcl/\1autoscalinggroup.vcl/' /etc/default/varnish
elif [ $YUM -eq 0 ] ; then
	sed -ri.orig -e '
	s/^([^#]*VARNISH_LISTEN_PORT)=.*$/\1=80/;
	s/^([^#]*VARNISH_VCL_CONF=\/etc\/varnish\/).*\.vcl/\1autoscalinggroup.vcl/;
	s/^([^#].*-f \/etc\/varnish\/).*\.vcl/\1autoscalinggroup.vcl/
	' /etc/sysconfig/varnish
fi



echo "${BACKEND_LAYER}" >/etc/varnish/backend-layer

curl -Lo /etc/varnish/generate-backends.sh https://github.com/jnerin/varnish-4-aws-ec2-autoscalinggroup/raw/master/varnish/generate-backends.sh
chmod 750 /etc/varnish/generate-backends.sh 
/etc/varnish/generate-backends.sh

service varnish start

# Amazon Linux with cronie
echo "* * * * * root /etc/varnish/generate-backends.sh" >>/etc/crontab
crontab /etc/crontab


