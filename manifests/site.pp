$ca_server = 'master-ca-primary.puppetlabs.vm'
$non_ca_servers = [
  'master-nonca1.puppetlabs.vm',
  'master-nonca2.puppetlabs.vm',
]

node 'master-ca-primary' {
  ## Populates the module with certificate stuff
  class { 'pe_shared_ca::update_module': }

  ## Sets up /facts in auth.conf
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
}

node 'haproxy' {
  ## Configure haproxy for our puppet masters.
  class { 'haproxy': }
  haproxy::listen { 'puppet00':
    ipaddress        => '*',
    ports            => '8140',
    collect_exported => false,
  }
  haproxy::balancermember { 'master-nonca1.puppetlabs.vm':
    listening_service => 'puppet00',
    ipaddresses       => '10.10.10.11',
    ports             => '8140',
    options           => 'check',
  }
  haproxy::balancermember { 'master-nonca2.puppetlabs.vm':
    listening_service => 'puppet00',
    ipaddresses       => '10.10.10.12',
    ports             => '8140',
    options           => 'check',
  }
}

node 'master-nonca1' {
  class { 'pe_shared_ca':
    ca_server => false,
  }
  # Manual steps:
  # 1. Run `puppet certificate generate --ca-location remote --dns-alt-names
  # puppet,puppet.${::domain},${::hostname},${::fqdn} --server ${ca_server}
  # ${::fqdn}` to generate new cert on CA.
  # 2. Run `puppet cert sign ${non_ca_master_fqdn} --allow-dns-alt-names` on
  # the CA to sign it.
  # 3. Run `puppet agent -t --server ${ca_server}` on the non-ca master to
  # retrieve signed cert.
}

node 'master-nonca2' {
  ## Trying out secondary CA
  class { 'pe_shared_ca':
    #ca_server => false,
    ca_server => true,
  }
  # Manual steps:
  # 1. Run `puppet master --no-daemonize --verbose` to generate new cert
  # locally, then ^C
  # 2. Run `service pe-httpd start` and `puppet agent -t`
}

node 'agent1' {
  ## Point to the ca_server
  ini_setting { 'ca_server setting':
    path    => '/etc/puppetlabs/puppet/puppet.conf',
    section => 'agent',
    setting => 'ca_server',
    value   => $::ca_server,
  }
}
