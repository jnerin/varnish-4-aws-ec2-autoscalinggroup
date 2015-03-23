# varnish 4 AWS EC2 AutoScalingGroup

Template for using Varnish 4 in an AWS AutoScalingGroup with autoconfiguration of the available backends.

```
+--------------------------------------------------+
|                                                  |
| Varnish Layer                                    |
|                                                  |
| +-----------+  +-----------+       +-----------+ |
| | Varnish 1 |  | Varnish 2 |  ...  | Varnish n | |
| |           |  |           |       |           | |
| +-+-+-+-----+  +-----------+       +-----------+ |
|   | | |                                          |
+--------------------------------------------------+
    | | |                                           
    | | |                                           
    | | |                                           
    | | +------------------------------+            
    | |                                |            
    | +-----------+                    |            
    |             |                    |            
+--------------------------------------------------+
|   |             |                    |           |
| Backend Layer   |                    |           |
|   |             |                    |           |
| +-v--------+  +-v--------+         +-v--------+  |
| | Apache 1 |  | Apache 2 |   ...   | Apache n |  |
| |          |  |          |         |          |  |
| +----------+  +----------+         +----------+  |
|                                                  |
+--------------------------------------------------+
```

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

The idea is that you create two auto scaling groups, one for the backend layer (Apache, nginx, whatever) and another for the Varnish layer, and in the auto scalong group of the Varnish layer you add a tag called "backend-layer" and put there the name of the autoscaling group that contains the backends. The [user-data script](user-data.sh) and [generate-backends.sh](varnish/generate-backends.sh) will read it. 

The user-data script assumes an Amazon Linux instance (but kind of works also in generic debian and rpm/yum distros) and installs aws command line tools, the jq json command line parser, and the official repository and last version of varnish. Then it tries to change the default vcl for Varnish to the one it downloads and lasts it adds a cronjob to /etc/crontab and adds it to cronie to launch generate-backends.sh every minute.

generate-backends.sh checks every minute for changes in the lists of running instances in the auto scaling group named in the tag backend-layer. If it detects a change it regenerates backends.vcl and loads the new vcl in varnish and switches over to it discarding the old vcls.

## Things to configure

This is mostly a WIP (Work In Progress) so a lot of things that shouldn't be hardcoded are, notably:

- user-data.sh
  - AWS_REGION
  - github urls of the vcls and scripts (you should configure them anyway)
- generate-backends.sh
  - You should configure the .probe section of the backends
  - backends director algorithm (another interesting choice migth be hash, choose your key wisely)
- autoscalinggroup.vcl
  - It's just an dummy vcl to show how to work with backends.vcl, you have to configure it for your needs.


