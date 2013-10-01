Vagrant.configure("2") do |config|
  {
    'ca1'       => '10.2.10.12',
    'lb'        => '10.2.10.10',
    'nonca1'    => '10.2.10.14',
    'postgres'  => '10.2.10.11',
    'puppetdb1' => '10.2.10.16',
    'console1'  => '10.2.10.18',
    'ca2'       => '10.2.10.13',
    'nonca2'    => '10.2.10.15',
    'puppetdb2' => '10.2.10.17',
    'console2'  => '10.2.10.19',
    'agent1'    => '10.2.10.20',
  }.each do |osname, ip|
    config.vm.define osname do |node|
      node.vm.box = 'centos-64-x64-vbox4210-nocm'
      node.vm.host_name = "#{osname}.puppetlabs.vm"
      if ['nonca1','nonca2'].include? osname
        node.vm.provider "virtualbox" do |v|
          v.customize ["modifyvm", :id, "--memory", 768]
        end
      else
        node.vm.provider "virtualbox" do |v|
          v.customize ["modifyvm", :id, "--memory", 384]
        end
      end
      node.vm.network "forwarded_port", guest: 9090, host: 9090 if osname == 'lb'
      node.vm.network "forwarded_port", guest: 9091, host: 9091 if osname == 'lb'
      node.vm.network "forwarded_port", guest: 443, host: 8443 if osname == 'console1'
      node.vm.network "forwarded_port", guest: 443, host: 9443 if osname == 'console2'
      node.vm.network :private_network, ip: ip
      node.vm.provision :shell do |shell|
        shell.path = "provision.sh"
      end
    end
  end
end
# vim: set sts=2 sw=2 ts=2 :
