# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant::Config.run do |config|
  {
    'master-ca-primary' => '10.10.10.10',
    'haproxy'           => '10.10.10.14',
    'master-nonca1'     => '10.10.10.11',
    'master-nonca2'     => '10.10.10.12',
    'agent1'            => '10.10.10.13',
  }.each do |osname, ip|
    config.vm.define osname do |node|
      node.vm.box = 'CentOS-6.4-x86_64-v20130309'
      node.vm.host_name = "#{osname}.puppetlabs.vm"
      node.vm.network :hostonly, ip
      node.vm.provision :shell, :path => "provision.sh"
    end
  end
end
