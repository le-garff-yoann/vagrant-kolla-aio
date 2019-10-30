#!/bin/bash

# TODO: Split the file?

sudo fdisk /dev/sda <<EOF
n
p
2


w
EOF
sudo partprobe

set -e

sudo yum install -y lvm2 epel-release

sudo pvcreate /dev/sda2
sudo vgcreate cinder-volumes /dev/sda2

# TODO: Create a bigger swapfile (or modify /swapfile)?
sudo -s <<EOF
cat > /usr/lib/sysctl.d/99-site.conf <<EOFF
vm.swappiness=0
EOFF
EOF
sudo sysctl --system

sudo yum makecache

sudo yum install -y \
    libffi-devel gcc openssl-devel git \
    python-devel python-pip libselinux-python ansible

sudo pip install -U pip

sudo pip install --ignore-installed kolla-ansible==$KOLLA_VERSION

cd ~

sudo mkdir -p /etc/kolla/
sudo chown -R $USER:$USER /etc/kolla

cp -r /usr/share/kolla-ansible/etc_examples/kolla /etc/
cp /usr/share/kolla-ansible/ansible/inventory/* .

if [[ -n "$KOLLA_EXTERNAL_FQDN_CERT" ]]
then
    echo -e "$KOLLA_EXTERNAL_FQDN_CERT" > "$HOME/full.pem"
elif [[ -n "$KOLLA_LETSENCRYPT_EMAIL" ]]
then
    sudo pip install certbot

    sudo certbot certonly -d "$KOLLA_EXTERNAL_FQDN" -nm "$KOLLA_LETSENCRYPT_EMAIL" --standalone --agree-tos
    sudo -s <<EOF
cat /etc/letsencrypt/live/$KOLLA_EXTERNAL_FQDN/privkey.pem /etc/letsencrypt/live/$KOLLA_EXTERNAL_FQDN/fullchain.pem > '$HOME/full.pem'
EOF

    sudo -s <<EOF
cat >> /etc/crontab <<EOFF
0 * * * * ( $(which certbot) renew && cat /etc/letsencrypt/live/$KOLLA_EXTERNAL_FQDN/privkey.pem /etc/letsencrypt/live/$KOLLA_EXTERNAL_FQDN/fullchain.pem > '$HOME/full.pem' ) | grep 'are not due for renewal yet' || docker restart haproxy
EOFF
EOF
fi

kolla-genpwd

cat > /etc/kolla/globals.yml <<EOF
kolla_base_distro: "centos"
kolla_install_type: "binary"
openstack_release: "$KOLLA_OPENSTACK_RELEASE"

network_interface: "eth1"
kolla_external_vip_interface: "eth0"
kolla_internal_vip_address: "10.10.10.253"
kolla_external_vip_address: "$(ip route get 1 | awk '{ print $NF; exit }')"
kolla_external_fqdn: "$KOLLA_EXTERNAL_FQDN"
kolla_enable_tls_external: "{{ 'yes' if '$KOLLA_EXTERNAL_FQDN_CERT$KOLLA_LETSENCRYPT_EMAIL' | length else 'no' }}"
kolla_external_fqdn_cert: "$HOME/full.pem"
kolla_enable_tls_internal: "no"

enable_openstack_core: "yes"
enable_haproxy: "yes"
enable_cinder: "yes"
enable_heat: "no"
enable_octavia: "yes"
enable_horizon_octavia: "{{ enable_octavia | bool }}"
enable_barbican: "yes"

nova_compute_virt_type: "qemu"

neutron_external_interface: "eth2"
neutron_tenant_network_types: "vxlan"
enable_neutron_dvr: "yes"
enable_neutron_provider_networks: "yes"

enable_cinder_backend_lvm: "{{ enable_cinder | bool }}"

glance_enable_rolling_upgrade: "no"

ironic_dnsmasq_dhcp_range:

tempest_image_id:
tempest_flavor_ref_id:
tempest_public_network_id:
tempest_floating_network_name:
EOF

git clone https://github.com/openstack/octavia.git \
    -b stable/$KOLLA_OPENSTACK_RELEASE

pushd octavia/

octavia_keystone_password=$(grep octavia_ca /etc/kolla/passwords.yml | awk '{ print $2 }')

sed -i "s/foobar/$octavia_keystone_password/g" bin/create_certificates.sh
bash bin/create_certificates.sh cert $PWD/etc/certificates/openssl.cnf

mkdir -p /etc/kolla/config/octavia
sudo cp cert/{private/cakey.pem,ca_01.pem,client.pem} /etc/kolla/config/octavia/

popd

set +e

sudo kolla-ansible -i all-in-one bootstrap-servers
sudo kolla-ansible -i all-in-one prechecks
sudo kolla-ansible -i all-in-one deploy || exit 1
sudo kolla-ansible post-deploy || exit 1

sudo yum install -y centos-release-openstack-$KOLLA_OPENSTACK_RELEASE

sudo yum install -y \
    openstack-selinux python-openstackclient \
    python-octaviaclient python-barbicanclient

set -e

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

curl -LO https://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
openstack image create \
    --public --disk-format qcow2 --container-format bare \
    --file cirros-0.4.0-x86_64-disk.img \
    cirros-0.4.0
rm -f cirros-0.4.0-x86_64-disk.img

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

openstack flavor create --private --ram 512 --vcpus 1 --disk 20 octavia
openstack keypair create \
    --os-username octavia \
    --os-password "$(cat /etc/kolla/passwords.yml | grep octavia_keystone_password | awk '{ print $2 }')" \
    octavia_ssh_key > octavia.pem
openstack security group create octavia
openstack security group rule create \
    --protocol icmp \
    octavia
openstack security group rule create \
    --protocol tcp --dst-port 5555 \
    --egress \
    octavia
openstack security group rule create \
    --protocol tcp --dst-port 9443 \
    --ingress \
    octavia

pushd octavia/

curl -LO http://tarballs.openstack.org/octavia/test-images/test-only-amphora-x64-haproxy-centos-7.qcow2
openstack image create \
    --private --protected --disk-format qcow2 --container-format bare \
    --tag amphora --file test-only-amphora-x64-haproxy-centos-7.qcow2 \
    amphora
rm -Rf test-only-amphora-x64-haproxy-centos-7.qcow2

pushd

cat >> /etc/kolla/globals.yml <<EOF

octavia_loadbalancer_topology: "SINGLE"
octavia_amp_boot_network_list: "$(openstack network show public -c id -f value)"
octavia_amp_secgroup_list: "$(openstack security group show octavia -c id -f value)"
octavia_amp_flavor_id: "$(openstack flavor show octavia -c id -f value)"
EOF

kolla-ansible -i all-in-one --tags octavia deploy

echo -e "\nOS_PASSWORD (admin): $OS_PASSWORD"