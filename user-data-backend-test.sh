#!/bin/bash
# The idea is that the user-data of the AutoScalingGroup is something like:
# curl -sL https://raw.githubusercontent.com/jnerin/varnish-4-aws-ec2-autoscalinggroup/master/user-data-backend-test.sh | bash -s --



cat > /opt/bitnami/apache2/htdocs/test.php <<'EOF'
<?php
$TTL=5;
header('Expires: ' . gmdate('D, d M Y H:i:s', time() + $TTL) . ' GMT');
header("Content-Type: text/plain; charset=utf-8");

$url = "http://169.254.169.254/latest/meta-data/instance-id";

$ch = curl_init();  
// set URL and other appropriate options  
curl_setopt($ch, CURLOPT_URL, $url);  
curl_setopt($ch, CURLOPT_HEADER, 0);  
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);  

// grab URL and pass it to the browser  

$output = curl_exec($ch);  

//echo $output;

// close curl resource, and free up system resources  
curl_close($ch);

echo "I'm instance " . $output . " (" . gmdate('D, d M Y H:i:s', time()) . " GMT)";
EOF
