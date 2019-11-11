# -*- mode: ruby -*-
# vi: set ft=ruby :

ROUTER_CPU = 1
ROUTER_MEMORY = 256
AIO_CPUS = ENV['VAGRANT_KOLLA_AIO_CPUS'] || 4
AIO_MEMORY = ENV['VAGRANT_KOLLA_AIO_MEMORY'] || 12288

MANAGEMENT_NETWORK_NAME = 'aio_management_network'
PROVIDER_NETWORK_NAME = 'aio_provider_network'

Vagrant.configure('2') do |config|
  config.vm.box = 'centos/7'

  config.vm.define :router do |node|
    node.vm.network :private_network,
      ip: '10.100.0.2',
      netmask: '255.255.0.0',
      virtualbox__intnet: PROVIDER_NETWORK_NAME

    node.vm.provision :shell do |sh|
      sh.path = 'router/main.sh'
    end

    node.vm.provider :libvirt do |lv|     
      lv.cpus = ROUTER_CPU
      lv.memory = ROUTER_MEMORY
    end

    node.vm.provider :virtualbox do |vb|
      vb.cpus = ROUTER_CPU
      vb.memory = ROUTER_MEMORY
    end
  end

  config.vm.define :aio do |node|
    node.vm.network :private_network,
      ip: '10.10.10.254',
      netmask: '255.255.0.0',
      virtualbox__intnet: MANAGEMENT_NETWORK_NAME
    node.vm.network :private_network,
      ip: '10.100.0.9',
      netmask: '255.255.0.0',
      virtualbox__intnet: PROVIDER_NETWORK_NAME
    node.vm.network :private_network,
      ip: '10.100.0.3',
      netmask: '255.255.0.0',
      virtualbox__intnet: PROVIDER_NETWORK_NAME
  
    node.vm.network :forwarded_port, host_ip: '0.0.0.0', guest: 80,   host: 80    # Horizon.
    node.vm.network :forwarded_port, host_ip: '0.0.0.0', guest: 443,  host: 443   # Horizon.
    node.vm.network :forwarded_port, host_ip: '0.0.0.0', guest: 8774, host: 8774  # Nova.
    node.vm.network :forwarded_port, host_ip: '0.0.0.0', guest: 6080, host: 6080  # Nova (noVNC).
    node.vm.network :forwarded_port, host_ip: '0.0.0.0', guest: 5000, host: 5000  # Keystone.
    node.vm.network :forwarded_port, host_ip: '0.0.0.0', guest: 9292, host: 9292  # Glance.
    node.vm.network :forwarded_port, host_ip: '0.0.0.0', guest: 9696, host: 9696  # Neutron.
    node.vm.network :forwarded_port, host_ip: '0.0.0.0', guest: 8780, host: 8780  # Placement.
    node.vm.network :forwarded_port, host_ip: '0.0.0.0', guest: 8776, host: 8776  # Cinder.
    node.vm.network :forwarded_port, host_ip: '0.0.0.0', guest: 9876, host: 9876  # Octavia.
  
    node.vm.provision :shell do |sh|
      sh.path = 'aio/unprivileged-main.sh'
      sh.env = {
        :KOLLA_OPENSTACK_RELEASE      => ENV['VAGRANT_KOLLA_AIO_OPENSTACK_RELEASE'] || 'stein',
        :KOLLA_EXTERNAL_FQDN          => ENV['VAGRANT_KOLLA_AIO_EXTERNAL_FQDN'],
        :KOLLA_EXTERNAL_FQDN_CERT     => ENV['VAGRANT_KOLLA_AIO_EXTERNAL_FQDN_CERT'],
        :KOLLA_LETSENCRYPT_EMAIL      => ENV['VAGRANT_KOLLA_AIO_LETSENCRYPT_EMAIL'],
        :KOLLA_VERSION                => ENV['VAGRANT_KOLLA_AIO_KOLLA_ANSIBLE_VERSION'] || '8.0.1'
      }
  
      sh.privileged = false
    end

    node.vm.provider :libvirt do |lv|
      lv.cpus = AIO_CPUS
      lv.memory = AIO_MEMORY

      lv.storage :file, :size => '160GB'

      lv.nested = true
    end

    node.disksize.size = '200GB'

    node.vm.provider :virtualbox do |vb|
      vb.cpus = AIO_CPUS
      vb.memory = AIO_MEMORY
    end
  end
end
