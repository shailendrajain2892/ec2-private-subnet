#!/bin/bash
sudo apt update -y &&
sudo apt install -y nginx
host_ip=`hostname -i | cut -d " " -f 1`
echo "Hello Nginx Demo from host : $host_ip" > /var/www/html/index.html
