# varnish-4-aws-ec2-autoscalinggroup
Template for using Varnish 4 in an AWS AutoScalingGroup with autoconfiguration of the available backends

## Problem

The problem of using varnish with either an ELB (Elastic Load Balancer) or to a layer of backend servers is that you must configure the ip addresses of the backends in each varnish instance, and you can't use dns names that resolve to more than 1 ip. So you can't put an ELB behind varnish directly because it's name resolves to more that 1 ip, and it even changes as it scales.

```
vcl.load test /etc/varnish/test.vcl
106        
Message from VCC-compiler:
Backend host "multi.localhost": resolves to too many addresses.
Only one IPv4 and one IPv6 are allowed.
Please specify which exact address you want to use, we found all of these:
        127.0.1.4
        127.0.1.3
        127.0.1.1
        127.0.1.2
('backends.vcl' Line 2 Pos 17)
        .host = "multi.localhost";
----------------#################-

Running VCC-compiler failed, exited with 2
VCL compilation failed
```

## Solution

Create a script to generate a backends.vcl file to be included from your main vcl, the skel would be something like that.

**backends.vcl**
```
backend b1 {
	.host = "10.0.0.1";
	.port = "80";
}
backend b2 {
	.host = "10.0.0.2";
	.port = "80";
}

sub backends_init {
	new vdir = directors.round_robin();
	vdir.add_backend(b1);
	vdir.add_backend(b2);
}
```

**main.vcl**
```
vcl 4.0;
import directors;
include "backends.vcl";

sub vcl_init {
	call backends_init;
}
# Rest of the vcl...
```

## Usage

Caveats, I have only tested this with Amazon Linux instances, I have tried to support both Debian & RedHat flavours, but so far it's pretty much untested in anything else.


