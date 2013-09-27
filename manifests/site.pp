node 'haproxy' {
  ## Configure haproxy for our puppet masters.
  class { 'haproxy': }

  ## HA puppet masters
  haproxy::listen { 'puppet00':
    ipaddress        => '*',
    ports            => '8140',
    collect_exported => false,
  }
  haproxy::balancermember { 'puppetmaster nonca1.puppetlabs.vm':
    listening_service => 'puppet00',
    ipaddresses       => '10.2.10.12',
    ports             => '8140',
    options           => 'check',
  }
  haproxy::balancermember { 'puppetmaster nonca2.puppetlabs.vm':
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
  haproxy::balancermember { 'activemq nonca1.puppetlabs.vm':
    listening_service => 'activemq00',
    ipaddresses       => '10.2.10.12',
    ports             => '61613',
    options           => 'check',
  }
  haproxy::balancermember { 'activemq nonca2.puppetlabs.vm':
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
    ipaddresses       => '10.2.10.16',
    ports             => '443',
    options           => [
      'check',
      'downinter 500',
    ],
  }
  haproxy::balancermember { 'console console2.puppetlabs.vm':
    listening_service => 'console00',
    ipaddresses       => '10.2.10.17',
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
    ipaddresses       => '10.2.10.16',
    ports             => '8141',
    options           => [
      'check',
      'downinter 500',
    ],
  }
  haproxy::balancermember { 'inventory console2.puppetlabs.vm':
    listening_service => 'console01',
    ipaddresses       => '10.2.10.17',
    ports             => '8141',
    options           => [
      'check',
      'backup',
    ],
  }

  ## PuppetDB
  haproxy::listen { 'puppetdb00':
    ipaddress        => '*',
    ports            => '8081',
    collect_exported => false,
  }
  haproxy::balancermember { 'puppetdb puppetdb1.puppetlabs.vm':
    listening_service => 'puppetdb00',
    ipaddresses       => '10.2.10.14',
    ports             => '8081',
    options           => [
      'check',
      'downinter 500',
    ],
  }
  haproxy::balancermember { 'puppetdb puppetdb2.puppetlabs.vm':
    listening_service => 'puppetdb00',
    ipaddresses       => '10.2.10.15',
    ports             => '8081',
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

node 'postgres' {
  class { 'postgresql::server':
    config_hash                    => {
      'ip_mask_deny_postgres_user' => '0.0.0.0/32',
      'ip_mask_allow_all_users'    => '0.0.0.0/0',
      'listen_addresses'           => '*',
      'postgres_password'          => 'postgres_password',
    }
  }
  postgresql::db { 'console_auth':
    user     => 'console_auth',
    password => postgresql_password('console_auth','puppetlabs'),
  }
  postgresql::db { 'console':
    user     => 'console',
    password => postgresql_password('console','puppetlabs'),
  }
  postgresql::db { 'pe-puppetdb':
    user     => 'pe-puppetdb',
    password => postgresql_password('pe-puppetdb','puppetlabs'),
  }
  #non-scaling extra
  service { 'pe-puppet':
    ensure => stopped,
  }
}

node /^nonca\d/ {
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
  #include pe_mcollective::role::master
  #include pe_accounts
  #include pe_mcollective
  #class { 'pe_httpd::nonca':
  #  proxy_ca_server => 'puppet.puppetlabs.vm',
  #  proxy_ca_port   => '8141',
  #}
  #class { 'pe_httpd::nonconsole':
  #  inventory_server => 'puppet.puppetlabs.vm',
  #  inventory_port   => '8141',
  #}
  #file_line { '/etc/puppetlabs/puppet-dashboard/external_node':
  #  path  => '/etc/puppetlabs/puppet-dashboard/external_node',
  #  line  => 'ENC_BASE_URL="https://puppet.puppetlabs.vm:443/nodes"',
  #  match => '^ENC_BASE_URL=.+$',
  #}
  ### inifile module is required
  #ini_setting { 'puppet.conf master reporturl':
  #  path    => '/etc/puppetlabs/puppet/puppet.conf',
  #  section => 'master',
  #  setting => 'reporturl',
  #  value   => 'https://puppet.puppetlabs.vm:443/reports/upload'
  #}
  service { 'pe-puppet':
    ensure => stopped,
  }

  ####################################################################

}

node /puppetdb\d/ {
  # classify?
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

  ### Second run (after signing cert)
  ##
  ## This stuff should come from the Console
  #include pe_mcollective::role::console
  #include pe_mcollective::role::master
  #include pe_accounts
  #include pe_mcollective

  ### Configure auth.conf
  #class { 'pe_httpd::ca':
  #  masterport       => '8141',
  #  master_certnames => [
  #    'nonca1.puppetlabs.vm',
  #    'nonca2.puppetlabs.vm',
  #  ],
  #}
  #class { 'pe_httpd::console':
  #  masterport => '8141',
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

  ## EXTRA: To make vagrant easier
  #file { '/etc/puppetlabs/puppet/autosign.conf':
  #  ensure  => file,
  #  content => "*\n",
  #}
  service { 'pe-puppet':
    ensure => stopped,
  }
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
