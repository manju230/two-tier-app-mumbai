#!/bin/bash
sudo yum update -y
sudo yum install -y httpd.x86_64
systemctl start httpd
systemctl enable httpd