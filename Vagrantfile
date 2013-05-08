boxes = Hash.new
boxes['debian'] = 'debian-607-x64-vbox4210'
boxes['centos'] = 'centos-64-x64-vbox4210'

Vagrant::Config.run do |config|
  {
    'debian' => {
      'master-ca1'    => '10.0.10.10',
      'master-nonca1' => '10.0.10.11',
      'master-nonca2' => '10.0.10.12',
      'haproxy'       => '10.0.10.13',
      'agent1'        => '10.0.10.14',
    },
    'centos' => {
      'master-ca1'    => '10.0.10.10',
      'master-nonca1' => '10.0.10.11',
      'master-nonca2' => '10.0.10.12',
      'haproxy'       => '10.0.10.13',
      'agent1'        => '10.0.10.14',
    }
  }.each do |platform, nodes|
    nodes.each do |osname, ip|
      config.vm.define "#{platform}-#{osname}" do |node|
        node.vm.box = boxes[platform]
        node.vm.host_name = "#{osname}.puppetlabs.vm"
        node.vm.network :hostonly, ip
        node.vm.provision :shell do |shell|
          shell.path = "provision.sh"
          shell.args = "#{ENV['peversion']} #{platform}"
        end
      end
    end
  end
end
# vim: set sts=2 sw=2 ts=2 :
