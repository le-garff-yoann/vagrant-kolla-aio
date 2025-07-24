#!/bin/bash

set -eo pipefail

# /etc/localtime is missing on "generic/rocky9:4.3.12".
rm -rf /etc/localtime
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
timedatectl set-timezone UTC
timedatectl set-local-rtc 0

cat > /usr/lib/sysctl.d/99-site.conf <<EOF
net.ipv4.ip_forward=1
EOF
sysctl --system

iptables -A FORWARD -i eth0 -j ACCEPT
iptables -A FORWARD -o eth0 -j ACCEPT
iptables -A FORWARD -i eth1 -j ACCEPT
iptables -A FORWARD -o eth1 -j ACCEPT

iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

dnf install -y iptables-services

iptables-save > /etc/sysconfig/iptables

systemctl mask firewalld.service
systemctl enable iptables.service ip6tables.service
