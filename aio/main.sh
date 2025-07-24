#!/bin/bash

set -eo pipefail

if [[ -e /dev/sdb ]]
then
    cinder_pv=/dev/sdb
else
    cinder_pv=/dev/vdb
fi

# /etc/localtime is missing on "generic/rocky9:4.3.12".
rm -rf /etc/localtime
sudo ln -sf /usr/share/zoneinfo/UTC /etc/localtime
sudo timedatectl set-timezone UTC
sudo timedatectl set-local-rtc 0

# Enforce an upgrade of "openssh-server" due to dependency issues.
sudo dnf install -y openssh-server lvm2 curl gcc dbus-devel glib2-devel python3-devel

sudo pvcreate "$cinder_pv"
sudo vgcreate cinder-volumes "$cinder_pv"

sudo -s <<EOF
cat > /etc/sysctl.d/99-site.conf <<EOFF
vm.swappiness=0
EOFF
EOF
sudo sysctl --system

sudo dnf install -y git python3-pip

sudo pip3 install -U pip setuptools docker
sudo pip3 install virtualenv certbot

cd ~

python3 -m virtualenv venv -p "$(which python3)"
# shellcheck disable=SC1091
. venv/bin/activate

pip install "ansible-core>=2.15,<2.16" "kolla-ansible>=18.7.0,<19"

sudo mkdir -p /etc/kolla
sudo chown -R "$USER:$USER" /etc/kolla

cp -r venv/share/kolla-ansible/etc_examples/kolla /etc/
cp venv/share/kolla-ansible/ansible/inventory/* .

if [[ -n $KOLLA_EXTERNAL_FQDN_CERT ]]
then
    echo -e "$KOLLA_EXTERNAL_FQDN_CERT" > "$HOME/full.pem"
elif [[ -n $KOLLA_LETSENCRYPT_EMAIL ]]
then
    sudo /usr/local/bin/certbot certonly -d "$KOLLA_EXTERNAL_FQDN" -nm "$KOLLA_LETSENCRYPT_EMAIL" --standalone --agree-tos
    sudo -s <<EOF
cat /etc/letsencrypt/live/$KOLLA_EXTERNAL_FQDN/privkey.pem /etc/letsencrypt/live/$KOLLA_EXTERNAL_FQDN/fullchain.pem > '$HOME/full.pem'
EOF

    sudo -s <<EOF
cat >> /etc/crontab <<EOFF
0 * * * * ( /usr/local/bin/certbot renew && cat /etc/letsencrypt/live/$KOLLA_EXTERNAL_FQDN/privkey.pem /etc/letsencrypt/live/$KOLLA_EXTERNAL_FQDN/fullchain.pem > '$HOME/full.pem' ) | grep 'are not due for renewal yet' || docker restart haproxy
EOFF
EOF
fi

kolla-genpwd

[[ "$(ip route get 1 2>/dev/null)" =~ src\ ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+) ]]

cat > /etc/kolla/globals.yml <<EOF
openstack_release: "$KOLLA_OPENSTACK_RELEASE"

kolla_base_distro: rocky
kolla_install_type: source

network_interface: eth1
kolla_external_vip_interface: eth0
kolla_internal_vip_address: "10.10.10.253"
kolla_external_vip_address: "${BASH_REMATCH[1]}"
kolla_external_fqdn: "{{ '$KOLLA_EXTERNAL_FQDN' if '$KOLLA_EXTERNAL_FQDN' | length > 0 else kolla_external_vip_address }}"
kolla_enable_tls_external: "{{ '$KOLLA_EXTERNAL_FQDN_CERT$KOLLA_LETSENCRYPT_EMAIL' | length > 0 }}"
kolla_external_fqdn_cert: "$HOME/full.pem"
kolla_enable_tls_internal: false

enable_openstack_core: true
enable_skyline: true
enable_haproxy: true
enable_cinder: true
enable_heat: false

nova_compute_virt_type: "$(grep -E 'vmx|svm' /proc/cpuinfo &>/dev/null && echo 'kvm' || echo 'qemu')"

neutron_external_interface: eth2
neutron_tenant_network_types: vxlan
enable_neutron_dvr: true
enable_neutron_provider_networks: true

enable_cinder_backend_lvm: "{{ enable_cinder | bool }}"

glance_enable_rolling_upgrade: false

ironic_dnsmasq_dhcp_range:

tempest_image_id:
tempest_flavor_ref_id:
tempest_public_network_id:
tempest_floating_network_name:
EOF

# Monkeypatching: `getent hosts $(hostname)` returns too much entries.
sudo -s <<EOF
cat > /etc/hosts <<EOFF
# BEGIN ANSIBLE GENERATED HOSTS
10.10.10.254 localhost.localdomain localhost
# END ANSIBLE GENERATED HOSTS
EOFF
EOF

sudo -s <<EOF
set -e

. venv/bin/activate

kolla-ansible -i all-in-one install-deps
kolla-ansible -i all-in-one bootstrap-servers
# kolla-ansible -i all-in-one prechecks # FIXME: Fails on "Checking if kolla_internal_vip_address and kolla_external_vip_address are not pingable from any node"
kolla-ansible -i all-in-one deploy
kolla-ansible post-deploy

chmod 644 /etc/kolla/admin-openrc.sh
EOF

sudo pip3 install \
    "git+https://github.com/openstack/python-openstackclient@stable/$KOLLA_OPENSTACK_RELEASE"

# shellcheck disable=SC1091
. /etc/kolla/admin-openrc.sh

openstack flavor create --ram 64 --vcpus 1 --disk 1 d1.pico
openstack flavor create --ram 128 --vcpus 1 --disk 2 d1.nano
openstack flavor create --ram 256 --vcpus 1 --disk 5 d1.micro
openstack flavor create --ram 512 --vcpus 1 --disk 10 d1.tiny
openstack flavor create --ram 1024 --vcpus 1 --disk 20 d1.small
openstack flavor create --ram 2048 --vcpus 2 --disk 40 d1.medium 
openstack flavor create --ram 4096 --vcpus 2 --disk 80 d1.large
openstack flavor create --ram 8192 --vcpus 4 --disk 160 d1.xlarge
openstack flavor create --ram 16384 --vcpus 6 --disk 320 d1.jumbo

curl -L https://download.cirros-cloud.net/0.6.3/cirros-0.6.3-x86_64-disk.img | \
openstack image create \
    --public --disk-format qcow2 --container-format bare \
    cirros-0.6.3

openstack network create \
    --share --external \
    --provider-network-type flat --provider-physical-network physnet1 \
    public
openstack subnet create \
    --subnet-range 10.100.0.0/16 --gateway 10.100.0.2 \
    --dhcp --allocation-pool start=10.100.0.10,end=10.100.255.254 \
    --dns-nameserver 8.8.8.8 --dns-nameserver 8.8.4.4 \
    --network public \
    public

echo -e "\nOS_PASSWORD (admin): $OS_PASSWORD"
