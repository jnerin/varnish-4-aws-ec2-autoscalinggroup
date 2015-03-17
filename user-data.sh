#!/bin/sh
apt-get install apt-transport-https
curl https://repo.varnish-cache.org/GPG-key.txt | apt-key add -
echo "deb https://repo.varnish-cache.org/ubuntu/ precise varnish-4.0" >> /etc/apt/sources.list.d/varnish-cache.list
apt-get update
apt-get -y install varnish awscli
mv /etc/varnish/default.vcl /etc/varnish/default-orig.vcl
wget -O /etc/varnish/default.vcl https://github.com/jnerin/varnish-4.0-configuration-templates/raw/master/default.vcl

