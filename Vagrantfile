Vagrant::Config.run do |config|
  {
    'dg'       => '10.2.10.10',
    'haproxy'  => '10.2.10.11',
    'mysql'    => '10.2.10.14',
    'console1' => '10.2.10.15',
    'console2' => '10.2.10.16',
    'nonca1'   => '10.2.10.12',
    'nonca2'   => '10.2.10.13',
    'agent1'   => '10.2.10.17',
  }.each do |osname, ip|
    config.vm.define osname do |node|
      node.vm.box = 'centos-64-x64-vbox4210'
      node.vm.host_name = "#{osname}.puppetlabs.vm"
      node.vm.forward_port 443, 8443 if osname == 'console1'
      node.vm.forward_port 443, 9443 if osname == 'console2'
      node.vm.network :hostonly, ip
      node.vm.customize ["modifyvm", :id, "--memory", 384]
      node.vm.provision :shell do |shell|
        shell.path = "provision.sh"
        shell.args = "2.8.1 centos"
      end
    end
  end
end
# vim: set sts=2 sw=2 ts=2 :
