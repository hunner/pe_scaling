$ca_server        = 'dg.puppetlabs.vm'
$non_ca_servers   = [ 'nonca1.puppetlabs.vm', 'nonca2.puppetlabs.vm', ]

node 'dg' {
  ## Populates the module with certificate stuff
  #class { 'pe_shared_ca::update_module': }
  #include pe_caproxy::ca

  #not needed for custom stuff
  include pe_accounts
  include pe_mcollective

  #needed on non-ca masters. They don't seem to get the master_role group in the Console?
  include pe_mcollective::role::master

  ## Sets up /facts in auth.conf for inventory service
  #class { 'auth_conf::defaults':
  #  master_certname => [
  #    $ca_server,
  #    $non_ca_servers,
  #  ]
  #}

  ## /certificate_status for console
  #auth_conf::acl { '/certificate_status':
  #  auth       => 'yes',
  #  acl_method => ['find','search', 'save', 'destroy'],
  #  allow      => 'pe-internal-dashboard',
  #  order      => 085,
  #}

  ## EXTRA: To make vagrant easier
  file { '/etc/puppetlabs/puppet/autosign.conf':
    ensure  => file,
    content => "*\n",
  }
  ini_setting { 'puppet.conf main manifest':
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'main',
    setting => 'manifest',
    value   => '/vagrant/manifests/site.pp',
  }
  ini_setting { 'puppet.conf main modulepath':
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'main',
    setting => 'modulepath',
    value   => '/vagrant/modules:/opt/puppet/share/puppet/modules',
  }
  service { 'pe-puppet':
    ensure => stopped,
  }
}

node 'haproxy' {
  ## Configure haproxy for our puppet masters.
  class { 'haproxy': }

  ## HA puppet masters
  haproxy::listen { 'puppet00':
    ipaddress        => '*',
    ports            => '8140',
    collect_exported => false,
  }
  haproxy::balancermember { 'puppetmaster master-nonca1.puppetlabs.vm':
    listening_service => 'puppet00',
    ipaddresses       => '10.2.10.12',
    ports             => '8140',
    options           => 'check',
  }
  haproxy::balancermember { 'puppetmaster master-nonca2.puppetlabs.vm':
    listening_service => 'puppet00',
    ipaddresses       => '10.2.10.13',
    ports             => '8140',
    options           => 'check',
  }

  ## HA activemq
  haproxy::listen { 'activemq00':
    ipaddress        => '*',
    ports            => '61613',
    collect_exported => false,
  }
  haproxy::balancermember { 'activemq master-nonca1.puppetlabs.vm':
    listening_service => 'activemq00',
    ipaddresses       => '10.2.10.12',
    ports             => '61613',
    options           => 'check',
  }
  haproxy::balancermember { 'activemq master-nonca2.puppetlabs.vm':
    listening_service => 'activemq00',
    ipaddresses       => '10.2.10.13',
    ports             => '61613',
    options           => 'check',
  }

  ## HA console
  haproxy::listen { 'console00':
    ipaddress        => '*',
    ports            => '443',
    collect_exported => false,
  }
  haproxy::balancermember { 'console console1.puppetlabs.vm':
    listening_service => 'console00',
    ipaddresses       => '10.2.10.15',
    ports             => '443',
    options           => [
      'check',
      'downinter 500',
    ],
  }
  haproxy::balancermember { 'console console2.puppetlabs.vm':
    listening_service => 'console00',
    ipaddresses       => '10.2.10.16',
    ports             => '443',
    options           => [
      'check',
      'backup',
    ],
  }
  ## Inventory Service
  haproxy::listen { 'console01':
    ipaddress        => '*',
    ports            => '8141',
    collect_exported => false,
  }
  haproxy::balancermember { 'inventory console1.puppetlabs.vm':
    listening_service => 'console01',
    ipaddresses       => '10.2.10.15',
    ports             => '8141',
    options           => [
      'check',
      'downinter 500',
    ],
  }
  haproxy::balancermember { 'inventory console2.puppetlabs.vm':
    listening_service => 'console01',
    ipaddresses       => '10.2.10.16',
    ports             => '8141',
    options           => [
      'check',
      'backup',
    ],
  }
  #extra
  service { 'pe-puppet':
    ensure => stopped,
  }
}

node 'mysql' {
  class { 'mysql::server':
    config_hash => {
      'root_password' => 'mysql_root_password',
      'bind_address'  => '0.0.0.0',
    }
  }
  database_user { 'root@console1.puppetlabs.vm':
    password_hash => mysql_password('mysql_root_password'),
    require       => Class['mysql::server'],
  }
  database_grant { 'root@console1.puppetlabs.vm':
    privileges => 'all',
  }
  database_user { 'console@console2.puppetlabs.vm':
    password_hash => mysql_password('DjUilvnVItEEaudcEIbV'),
    require       => Class['mysql::server'],
  }
  database_grant { 'console@console2.puppetlabs.vm/console':
    privileges => 'all',
  }
  database_grant { 'console@console2.puppetlabs.vm/console_inventory_service':
    privileges => 'all',
  }
  database_user { 'console_auth@console2.puppetlabs.vm':
    password_hash => mysql_password('368Mg6NcQ5PVPuiUSi1T'),
    require       => Class['mysql::server'],
  }
  database_grant { 'console_auth@console2.puppetlabs.vm/console_auth':
    privileges => 'all',
  }
  #extra
  service { 'pe-puppet':
    ensure => stopped,
  }
}

node /^console\d/ {
  ####################################################################

  ## First run (before manual steps)
  #class { 'pe_shared_ca':
  #  ca_server => true,
  #}

  # Manual steps:
  # 1. Run `puppet master --no-daemonize -v` to generate new cert with dns alt names
  # 2. Press ^C to kill the puppet master when it says "Starting Puppet master"
  # 3. Run `service pe-httpd start` to start the master with the new cert
  # 4. Add 'custom_auth_conf=false' parameter on the DG

  ## Second run (after signing cert)
  #
  # This stuff should come from the Console
  include pe_mcollective::role::console
  include pe_mcollective::role::master
  include pe_accounts
  include pe_mcollective

  ## Configure auth.conf
  class { 'pe_httpd::ca':
    masterport       => '8141',
    master_certnames => [
      'nonca1.puppetlabs.vm',
      'nonca2.puppetlabs.vm',
    ],
  }
  class { 'pe_httpd::console':
    masterport => '8141',
  }

  ini_setting { 'puppet.conf agent server':
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'agent',
    setting => 'server',
    value   => $::ca_server,
  }
  ini_setting { 'puppet.conf main dns_alt_names':
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'main',
    setting => 'dns_alt_names',
    value   => "puppet,puppet.${::domain},${::hostname},${::fqdn}",
  }

  ## EXTRA: To make vagrant easier
  file { '/etc/puppetlabs/puppet/autosign.conf':
    ensure  => file,
    content => "*\n",
  }
  service { 'pe-puppet':
    ensure => stopped,
  }
}

node /^nonca\d/ {
  import 'activemq_brokers.pp'
  ####################################################################

  ## First run (before manual steps)
  #class { 'pe_shared_ca':
  #  ca_server => false,
  #}
  #ini_setting { 'puppet.conf agent server':
  #  path    => '/etc/puppetlabs/puppet/puppet.conf',
  #  section => 'agent',
  #  setting => 'server',
  #  value   => $::ca_server,
  #}
  #ini_setting { 'puppet.conf main dns_alt_names':
  #  path    => '/etc/puppetlabs/puppet/puppet.conf',
  #  section => 'main',
  #  setting => 'dns_alt_names',
  #  value   => "puppet,puppet.${::domain},${::hostname},${::fqdn}",
  #}

  # Manual steps:
  # 1. On non-CA: Run `puppet agent -t` to generate new cert with dns alt names on DG
  # 2. On DG:     Run `puppet cert sign ${non_ca_master_fqdn} --allow-dns-alt-names`
  # 3. On non-CA: Run `puppet agent -t` to retrieve signed cert.

  ## Second run (after signing cert)
  # This stuff should come from the Console
  include pe_mcollective::role::master
  include pe_accounts
  include pe_mcollective
  class { 'pe_httpd::nonca':
    proxy_ca_server => 'puppet.puppetlabs.vm',
    proxy_ca_port   => '8141',
  }
  class { 'pe_httpd::nonconsole':
    inventory_server => 'puppet.puppetlabs.vm',
    inventory_port   => '8141',
  }
  file_line { '/etc/puppetlabs/puppet-dashboard/external_node':
    path  => '/etc/puppetlabs/puppet-dashboard/external_node',
    line  => 'ENC_BASE_URL="https://puppet.puppetlabs.vm:443/nodes"',
    match => '^ENC_BASE_URL=.+$',
  }
  ## inifile module is required
  ini_setting { 'puppet.conf master reporturl':
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'master',
    setting => 'reporturl',
    value   => 'https://puppet.puppetlabs.vm:443/reports/upload'
  }
  service { 'pe-puppet':
    ensure => stopped,
  }

  ####################################################################

}

node 'agent1' {
  ## Point to the ca_server for certificates
  #ini_setting { 'ca_server setting':
  #  path    => '/etc/puppetlabs/puppet/puppet.conf',
  #  section => 'agent',
  #  setting => 'ca_server',
  #  value   => $::ca_server,
  #}
  service { 'pe-puppet':
    ensure => stopped,
  }
}
