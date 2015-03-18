#!/bin/bash

# BACKEND_LAYER="$(cat /etc/varnish/backend-layer)"

VARNISH_MAINFILE="/etc/varnish/autoscalinggroup.vcl"
VARNISH_BACKENDSFILE="/etc/varnish/backends.vcl"

BACKEND_LAYER="$(aws ec2 describe-tags  --filters "Name=resource-id,Values=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)" "Name=key,Values=backend-layer" | jq -r ".Tags[0].Value")"
BACKEND_LAYER="ASG-Apache"


BACKENDS_DEFS=""
BACKENDS_INIT="
sub backends_init {
	new vdir = directors.round_robin();
"

BACKEND_CONFIG="
    	.port = \"80\";
	.max_connections = 300; # That's it
	.probe = {
		#.url = \"/\"; # short easy way (GET /)
		# We prefer to only do a HEAD /
		.request = 
			\"HEAD / HTTP/1.1\"
			\"Host: localhost\"
			\"Connection: close\";      	
		.interval = 5s; # check the health of each backend every 5 seconds
		.timeout = 1s; # timing out after 1 second.
		# If 3 out of the last 5 polls succeeded the backend is considered healthy, otherwise it will be marked as sick
		.window = 5;
		.threshold = 3;
		}
	.first_byte_timeout     = 300s;   # How long to wait before we receive a first byte from our backend?
	.connect_timeout        = 5s;     # How long to wait for a backend connection?
	.between_bytes_timeout  = 2s;     # How long to wait between bytes received from our backend?

"
INSTANCES=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names "${BACKEND_LAYER}" | jq -r ".AutoScalingGroups[].Instances[].InstanceId")

MD5SUM_STATEFILE="/var/lib/misc/generate-backends.md5sum"
# Check md5sum of this list vs the value stored in /var/lib/misc/generate-backends.md5sum
MD5SUM_NEW="$(echo $INSTANCES | sort |md5sum | cut -d " " -f 1)"
if [ -e $MD5SUM_STATEFILE ] ; then
	MD5SUM_OLD="$(< $MD5SUM_STATEFILE )"
	if [ "$MD5SUM_NEW" == "$MD5SUM_OLD" ] ; then
		# Nothing to do
		exit
	else
		echo $MD5SUM_NEW > $MD5SUM_STATEFILE
	fi
else
	echo $MD5SUM_NEW > $MD5SUM_STATEFILE
fi

# We haven't exited, so continue to generate the file

for ID in $INSTANCES ; do
	#aws ec2 describe-instances --instance-ids $ID --query Reservations[].Instances[].PublicIpAddress --output text 
	IP="$(aws ec2 describe-instances --instance-ids $ID --query Reservations[].Instances[].PrivateIpAddress --output text )"
	BACKEND_NAME="$(echo "${ID}_$IP" | tr -- -. __)"
	echo "$ID -> $IP ($BACKEND_NAME)"
	BACKENDS_DEFS+="backend $BACKEND_NAME {
	.host = \"${IP}\";
	$BACKEND_CONFIG
}
"
	BACKENDS_INIT+="
	vdir.add_backend($BACKEND_NAME);"
done
BACKENDS_INIT+="
}"

cat > /etc/varnish/backends.vcl <<EOF
$BACKENDS_DEFS
$BACKENDS_INIT
EOF


#exit

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
varnishadm vcl.load vcl-${TIMESTAMP} $VARNISH_MAINFILE
varnishadm vcl.use vcl-${TIMESTAMP}
for i in $(varnishadm vcl.list |egrep -v "^active" |awk '{print $3;}') ; do 
	varnishadm vcl.discard "${i}"
done

logger --priority user.notice "$BACKEND_NAME varnish vcl updated with $(echo $INSTANCES | wc --lines) backends ($(echo $INSTANCES |paste --serial --delimiter=, ))"
