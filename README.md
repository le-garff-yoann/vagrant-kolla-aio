# vagrant-kolla-aio

Deploy an All-In-One (AIO) setup of OpenStack (thanks to [Kolla-Ansible](https://docs.openstack.org/kolla-ansible/latest/)) within Vagrant.

While Kolla-Ansible is primarily intended for production use, **this setup is designed solely for testing.**

## Prerequisites

Your Vagrant setup must support the [`disks`](https://www.vagrantup.com/docs/experimental#disks) feature
(only required when using the VirtualBox provider).

## Setup

```bash
# You can also use the libvirt provider by setting:
# VAGRANT_DEFAULT_PROVIDER=libvirt
# export VAGRANT_DEFAULT_PROVIDER

VAGRANT_KOLLA_AIO_EXTERNAL_FQDN=openstack.example.com \
    sh vagrant.sh up
```

| ENV                                    | Mandatory? | Default value | Description                                                                                                                   |
| -------------------------------------- | ---------- | ------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| `VAGRANT_KOLLA_AIO_EXTERNAL_FQDN`      | ☓          | None          | External URL for accessing the OpenStack control plane.                                                                       |
| `VAGRANT_KOLLA_AIO_LETSENCRYPT_EMAIL`  | ☓          | None          | Enables the external TLS termination. It must be completed with the email address associated with your Let's Encrypt account. |
| `VAGRANT_KOLLA_AIO_EXTERNAL_FQDN_CERT` | ☓          | None          | Enables the external TLS termination. It must be completed with a private key and a fullchain certificate (PEM format).       |
| `VAGRANT_KOLLA_AIO_CPUS`               | ✓          | `4`           | CPUs                                                                                                                          |
| `VAGRANT_KOLLA_AIO_MEMORY`             | ✓          | `12288` (mb)  | RAM                                                                                                                           |
| `VAGRANT_KOLLA_AIO_ENABLE_NESTED_VIRT` | ✓          | `false`       | Enables nested virtualization on All-In-One OpenStack node.                                                                   |

The setup will display the _admin_ password upon completion.

## OpenStack control plane

### Web dashboards

- Access Horizon at `http://localhost` or `https://$VAGRANT_KOLLA_AIO_EXTERNAL_FQDN`.
- Access Skyline at `http://localhost:9999` or `https://$VAGRANT_KOLLA_AIO_EXTERNAL_FQDN:9999`.

### CLI

```bash
sh vagrant.sh ssh

. /etc/kolla/admin-openrc.sh

openstack endpoint list # List endpoints.
```
