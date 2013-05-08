$ca_server        = 'master-ca1.puppetlabs.vm'
$non_ca_servers   = [ 'master-nonca1.puppetlabs.vm', 'master-nonca2.puppetlabs.vm', ]
$activemq_brokers = 'master-ca1.puppetlabs.vm,master-nonca1.puppetlabs.vm,master-nonca2.puppetlabs.vm'

node 'master-ca1' {
  ## Populates the module with certificate stuff
  class { 'pe_shared_ca::update_module': }
  #include pe_caproxy::ca

  #not needed for custom stuff
  include pe_accounts
  include pe_mcollective

  #needed on non-ca masters. They don't seem to get the master_role group in the Console?
  include pe_mcollective::role::master

  ## Sets up /facts in auth.conf for inventory service
  class { 'auth_conf::defaults':
    master_certname => [
      $ca_server,
      $non_ca_servers,
    ]
  }

  ## /certificate_status for dashboard
  auth_conf::acl { '/certificate_status':
    auth       => 'yes',
    acl_method => ['find','search', 'save', 'destroy'],
    allow      => 'pe-internal-dashboard',
    order      => 085,
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

node /^master-nonca\d/ {
  ## First run (before manual steps)
  class { 'pe_shared_ca':
    ca_server => false,
  }
  ## inifile module is required
  ini_setting { 'server setting':
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'agent',
    setting => 'server',
    value   => $::ca_server,
  }
  ini_setting { 'dns_alt_names setting':
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'main',
    setting => 'dns_alt_names',
    value   => "puppet,puppet.${::domain},${::hostname},${::fqdn}",
  }

  #include pe_caproxy::master

  # Manual steps:
  # 0. Edit puppetmaster.conf to point to correct crl.pem
  # 1. On non-CA: Run `puppet agent -t` to generate new cert with dns alt names on CA
  # 2. On CA:     Run `puppet cert sign ${non_ca_master_fqdn} --allow-dns-alt-names`
  # 3. On non-CA: Run `puppet agent -t` to retrieve signed cert.
  # 4. On non-CA: Run `service pe-httpd start` to start the master with the new cert

  ## Second run (after signing cert)
  #
  # This stuff should come from the Console
  include pe_mcollective::role::master
  include pe_accounts
  include pe_mcollective
  #service { 'pe-puppet':
  #  ensure => stopped,
  #}
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
    ipaddresses       => '10.10.10.11',
    ports             => '8140',
    options           => 'check',
  }
  haproxy::balancermember { 'puppetmaster master-nonca2.puppetlabs.vm':
    listening_service => 'puppet00',
    ipaddresses       => '10.10.10.12',
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
    ipaddresses       => '10.10.10.11',
    ports             => '61613',
    options           => 'check',
  }
  haproxy::balancermember { 'activemq master-nonca2.puppetlabs.vm':
    listening_service => 'activemq00',
    ipaddresses       => '10.10.10.12',
    ports             => '61613',
    options           => 'check',
  }

  #extra
  service { 'pe-puppet':
    ensure => stopped,
  }
}

node 'agent1' {
  ## Point to the ca_server for certificates
  ini_setting { 'ca_server setting':
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'agent',
    setting => 'ca_server',
    value   => $::ca_server,
  }
  service { 'pe-puppet':
    ensure => stopped,
  }
}
