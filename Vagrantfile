# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.hostname = 'service-qa'
  config.vm.box = "precise64"
  config.vm.box_url = 'http://cloud-images.ubuntu.com/vagrant/precise/current/precise-server-cloudimg-amd64-vagrant-disk1.box'

  config.ssh.forward_agent = true

  config.vm.provision :shell, path: '.vagrant-provision.sh'
  config.vm.define 'service-qa' do |host|
  end

  config.vm.provider :virtualbox do |vb|
    vb.gui = true
    vb.customize [ "guestproperty", "set", :id, "/VirtualBox/GuestAdd/VBoxService/--timesync-set-threshold", 10000 ]
  end
end
