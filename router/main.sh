#!/bin/bash

set -e

cat > /usr/lib/sysctl.d/99-site.conf <<EOF
net.ipv4.ip_forward=1
EOF
sysctl --system

iptables -A FORWARD -o eth0 -j ACCEPT
iptables -A FORWARD -i eth1 -j ACCEPT
iptables -A FORWARD -o eth1 -j ACCEPT
iptables -A FORWARD -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -j ACCEPT

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

yum install -y iptables-services

iptables-save > /etc/sysconfig/iptables

systemctl mask firewalld.service
systemctl enable iptables.service ip6tables.service
