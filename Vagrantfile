# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|
  config.vm.box = 'centos/7'

  config.vm.define :router do |node|
    node.vm.network :private_network, ip: '10.100.0.2', netmask: '255.255.0.0', virtualbox__intnet: 'aio_shared'

    node.vm.provision :shell do |sh|
      sh.path = 'router/main.sh'
    end

    node.vm.provider :virtualbox do |vb|
      vb.cpus = 1
      vb.memory = 256

      vb.customize [ 'modifyvm', :id, '--nicpromisc1', 'allow-all' ]
      vb.customize [ 'modifyvm', :id, '--nicpromisc2', 'allow-all' ]
    end
  end

  config.vm.define :aio do |node|
    node.vm.network :private_network, ip: '10.10.10.254', virtualbox__intnet: 'aio_internal'
    node.vm.network :private_network, auto_config: false, virtualbox__intnet: 'aio_shared'
    node.vm.network :private_network, ip: '10.100.0.3', netmask: '255.255.0.0', virtualbox__intnet: 'aio_shared'
  
    node.vm.network :forwarded_port, guest: 80,   host: 80    # Horizon.
    node.vm.network :forwarded_port, guest: 443,  host: 443   # Horizon.
    node.vm.network :forwarded_port, guest: 8774, host: 8774  # Nova.
    node.vm.network :forwarded_port, guest: 6080, host: 6080  # Nova (noVNC).
    node.vm.network :forwarded_port, guest: 5000, host: 5000  # Keystone.
    node.vm.network :forwarded_port, guest: 9292, host: 9292  # Glance.
    node.vm.network :forwarded_port, guest: 9696, host: 9696  # Neutron.
    node.vm.network :forwarded_port, guest: 8780, host: 8780  # Placement.
    node.vm.network :forwarded_port, guest: 8776, host: 8776  # Cinder.
    node.vm.network :forwarded_port, guest: 9876, host: 9876  # Octavia.
  
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

    node.vm.provider :virtualbox do |vb|
      vb.cpus = ENV['VAGRANT_KOLLA_AIO_CPUS'] || 4
      vb.memory = ENV['VAGRANT_KOLLA_AIO_MEMORY'] || 12288

      vb.customize [ 'modifyvm', :id, '--nicpromisc1', 'allow-all' ]
      vb.customize [ 'modifyvm', :id, '--nicpromisc2', 'allow-all' ]
      vb.customize [ 'modifyvm', :id, '--nicpromisc3', 'allow-all' ]
      vb.customize [ 'modifyvm', :id, '--nicpromisc3', 'allow-all' ]
    end

    node.disksize.size = '200GB'
  end
end
