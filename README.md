# vagrant-kolla-aio

Deploy an All-In-One (AIO) setup of OpenStack (thanks to [Kolla-Ansible](https://docs.openstack.org/kolla-ansible/latest/)) within Vagrant.

Although Kolla-Ansible is mainly used for production deployment **this setup is only meant for testing purposes.**

## Prerequisites

```bash
vagrant plugin install vagrant-disksize
```

## Setup

```bash
VAGRANT_KOLLA_AIO_EXTERNAL_FQDN=mydomain.io \
    vagrant up
```

| ENV | Mandatory? | Default value | Description |
|-|-|-|-|
| `VAGRANT_KOLLA_AIO_OPENSTACK_RELEASE` | ☓ | `stein` | Version of OpenStack to install. |
| `VAGRANT_KOLLA_AIO_EXTERNAL_FQDN` | ✓ | None | URL through which OpenStack will be accessed from outside |
| `VAGRANT_KOLLA_AIO_LETSENCRYPT_EMAIL` | ☓ | None | Enables the external TLS termination. It must be completed with the email address associated with your Let's Encrypt account |
| `VAGRANT_KOLLA_AIO_EXTERNAL_FQDN_CERT` | ☓ | None | Enables the external TLS termination. It must be completed with a private key and a fullchain certificate (PEM format) |
| `VAGRANT_KOLLA_AIO_KOLLA_ANSIBLE_VERSION` | ☓ | `8.0.1` | Version of [kolla-ansible](https://pypi.org/project/kolla-ansible/) to install. |
| `VAGRANT_KOLLA_AIO_CPUS` | ☓ | `4` | CPUs |
| `VAGRANT_KOLLA_AIO_MEMORY` | ☓ | `12288` (mb) | RAM |

The *admin* password will be displayed out at the end of the setup.

## OpenStack

### Horizon

Connect to it through `http://$VAGRANT_KOLLA_AIO_KOLLA_EXTERNAL_FQDN`.

### CLI

```bash
vagrant ssh

. /etc/kolla/admin-openrc.sh

openstack endpoint list # List endpoints.
```
