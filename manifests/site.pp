node 'master-ca-primary' {
  class { 'pe_shared_ca::update_module': }

  include request_manager
  Auth_conf::Acl <| title == '/certificate_status' |> {
    allow      => [
      'pe-internal-dashboard',
      'master-nonca1.puppetlabs.vm',
      'master-nonca2.puppetlabs.vm',
    ],
  }
  auth_conf::acl { '/facts':
    allow      => [
      'master-ca-primary.puppetlabs.vm',
      'master-nonca1.puppetlabs.vm',
      'master-nonca2.puppetlabs.vm',
    ],
  }

  file { '/etc/puppetlabs/puppet/autosign.conf':
    ensure  => file,
    content => "*\n",
  }
}

node 'haproxy' {
  class { 'haproxy': }
  haproxy::listen { 'puppet00':
    ipaddress        => '10.10.10.14',
    ports            => '8140',
    collect_exported => false,
  }
  haproxy::balancermember { 'master-nonca1.puppetlabs.vm':
    listening_service => 'puppet00',
    server_names      => 'master-nonca1',
    ipaddresses       => '10.10.10.11',
    ports             => '8140',
    options           => 'check'
  }
  haproxy::balancermember { 'master-nonca2.puppetlabs.vm':
    listening_service => 'puppet00',
    server_names      => 'master-nonca2',
    ipaddresses       => '10.10.10.12',
    ports             => '8140',
    options           => 'check'
  }
}

node 'master-nonca1' {
  class { 'pe_shared_ca':
    ca_server => false,
  }
}

node 'master-nonca2' {
  class { 'pe_shared_ca':
    ca_server => false,
  }
}

node 'agent1' {
}
