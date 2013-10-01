node 'lb' {
  ## Special vagrant stuff
  file { '/etc/puppetlabs/puppet/ssl/certs/lb.puppetlabs.vm.pem':
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0644',
    source => '/vagrant/files/ssl/certs/lb.puppetlabs.vm.pem',
    before => Class['apache'],
  }
  file { '/etc/puppetlabs/puppet/ssl/public_keys/lb.puppetlabs.vm.pem':
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0644',
    source => '/vagrant/files/ssl/public_keys/lb.puppetlabs.vm.pem',
    before => Class['apache'],
  }
  file { '/etc/puppetlabs/puppet/ssl/private_keys/lb.puppetlabs.vm.pem':
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0600',
    source => '/vagrant/files/ssl/private_keys/lb.puppetlabs.vm.pem',
    before => Class['apache'],
  }

  ## Load balance http connections with apache
  class { 'apache': }

  ## HA puppet CAs
  apache::balancer { 'puppet_ca':
    collect_exported => false,
  }
  apache::balancermember { 'ca for ca1':
    balancer_cluster => 'puppet_ca',
    url              => "http://ca1.puppetlabs.vm:18140",
  }
  apache::balancermember { 'ca for ca2':
    balancer_cluster => 'puppet_ca',
    url              => "http://ca2.puppetlabs.vm:18140",
    options          => ['status=+H'],
  }

  ## HA puppet masters
  apache::balancer { 'puppet_master':
    collect_exported => false,
  }
  apache::balancermember { 'master for nonca1':
    balancer_cluster => 'puppet_master',
    url              => "http://nonca1.puppetlabs.vm:18140",
  }
  apache::balancermember { 'master for nonca2':
    balancer_cluster => 'puppet_master',
    url              => "http://nonca2.puppetlabs.vm:18140",
  }

  ## HA CA/master vhost
  apache::vhost { 'CAs and masters':
    servername      => 'puppet.puppetlabs.vm',
    ssl             => true,
    ssl_cert        => "/etc/puppetlabs/puppet/ssl/certs/${::fqdn}.pem",
    ssl_key         => "/etc/puppetlabs/puppet/ssl/private_keys/${::fqdn}.pem",
    ssl_ca          => '/etc/puppetlabs/puppet/ssl/ca/ca_crt.pem',
    port            => '8140',
    docroot         => '/dne',
    request_headers => [
      'set X-SSL-Subject %{SSL_CLIENT_S_DN}e',
      'set X-Client-DN %{SSL_CLIENT_S_DN}e',
      'set X-Client-Verify %{SSL_CLIENT_VERIFY}e',
    ],
    custom_fragment => '
  ProxyRequests off
  ProxyPass      /balancer-manager !
  ProxyPass      /server-status !
  ProxyPassMatch ^/([^/]+/certificate.*)$ balancer://puppet_ca/$1
  ProxyPass      / balancer://puppet_master/
  <Location      />
    ProxyPassReverse /
  </Location>
  ProxyPreserveHost On
  SSLVerifyClient optional
  SSLVerifyDepth  1
  SSLOptions      +StdEnvVars +ExportCertData',
  }

  ## Just for testing/monitoring
  apache::vhost { 'monitor':
    servername => 'puppet.puppetlabs.vm',
    port       => '9091',
    docroot    => '/dne',
    custom_fragment => '
  <Location /balancer-manager>
    SetHandler balancer-manager
    Order allow,deny
    Allow from all
  </Location>
  <Location /server-status>
    SetHandler server-status
    Order allow,deny
    Allow from all
  </Location>
  ProxyStatus On',
  }

  ## Load balance tcp connections with haproxy
  class { 'haproxy': }

  ## HA consoles
  haproxy::listen { 'console00':
    ipaddress        => '*',
    ports            => '443',
    collect_exported => false,
  }
  haproxy::balancermember { 'console console1.puppetlabs.vm':
    listening_service => 'console00',
    ipaddresses       => '10.2.10.18',
    ports             => '443',
    options           => [
      'check',
      'downinter 500',
    ],
  }
  haproxy::balancermember { 'console console2.puppetlabs.vm':
    listening_service => 'console00',
    ipaddresses       => '10.2.10.19',
    ports             => '443',
    options           => [
      'check',
      'backup',
    ],
  }

  ## HA activemq
  haproxy::listen { 'activemq00':
    ipaddress        => '*',
    ports            => '61613',
    collect_exported => false,
  }
  haproxy::balancermember { 'activemq nonca1.puppetlabs.vm':
    listening_service => 'activemq00',
    ipaddresses       => '10.2.10.14',
    ports             => '61613',
    options           => 'check',
  }
  haproxy::balancermember { 'activemq nonca2.puppetlabs.vm':
    listening_service => 'activemq00',
    ipaddresses       => '10.2.10.15',
    ports             => '61613',
    options           => 'check',
  }

  ## HA PuppetDB
  haproxy::listen { 'puppetdb00':
    ipaddress        => '*',
    ports            => '8081',
    collect_exported => false,
  }
  haproxy::balancermember { 'puppetdb puppetdb1.puppetlabs.vm':
    listening_service => 'puppetdb00',
    ipaddresses       => '10.2.10.16',
    ports             => '8081',
    options           => [
      'check',
      'downinter 500',
    ],
  }
  haproxy::balancermember { 'puppetdb puppetdb2.puppetlabs.vm':
    listening_service => 'puppetdb00',
    ipaddresses       => '10.2.10.17',
    ports             => '8081',
    options           => [
      'check',
      'backup',
    ],
  }

  #vagrant extra
  haproxy::listen { 'stats':
    ipaddress => $::ipaddress,
    ports    => '9090',
    options  => {
      'mode'  => 'http',
      'stats' => ['uri /', 'auth puppet:puppet']
      },
  }
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

node /^ca\d/ {
  if $::clientcert == 'ca1.puppetlabs.vm' {
    class { 'pe_shared_ca::update_module': }
    exec { 'generate lb cert':
      command   => '/opt/puppet/bin/puppet certificate generate --ca-location local lb.puppetlabs.vm --dns-alt-names puppet,puppet.puppetlabs.vm',
      creates   => '/etc/puppetlabs/puppet/ssl/certificate_requests/lb.puppetlabs.vm.pem',
      logoutput => 'on_failure',
      before    => Exec['sign lb cert'],
    }
    exec { 'sign lb cert':
      command   => '/opt/puppet/bin/puppet cert sign lb.puppetlabs.vm --allow-dns-alt-names',
      creates   => '/etc/puppetlabs/puppet/ssl/ca/signed/lb.puppetlabs.vm.pem',
      logoutput => 'on_failure',
    }
    file { [
      '/vagrant/files',
      '/vagrant/files/ssl',
      '/vagrant/files/ssl/certs',
      '/vagrant/files/ssl/public_keys',
      '/vagrant/files/ssl/private_keys',
    ]:
      ensure => directory,
    }
    file { '/vagrant/files/ssl/certs/lb.puppetlabs.vm.pem':
      source => '/etc/puppetlabs/puppet/ssl/ca/signed/lb.puppetlabs.vm.pem',
    }
    file { '/vagrant/files/ssl/public_keys/lb.puppetlabs.vm.pem':
      source => '/etc/puppetlabs/puppet/ssl/public_keys/lb.puppetlabs.vm.pem',
    }
    file { '/vagrant/files/ssl/private_keys/lb.puppetlabs.vm.pem':
      source => '/etc/puppetlabs/puppet/ssl/private_keys/lb.puppetlabs.vm.pem',
    }
  } else {
    class { 'pe_shared_ca':
      ca_server => true,
    }
  }

  ## Configure non-ssl on 18140
  file { '/etc/puppetlabs/httpd/conf.d/puppetmaster-nossl.conf':
    ensure  => file,
    owner   => 'root',
    group   => 'pe-puppet',
    mode    => '0644',
    content => 'Listen 18140
<VirtualHost *:18140>
    ServerAlias puppet puppet.puppetlabs.vm
    SSLEngine off

    SetEnvIf X-Client-Verify "(.*)" SSL_CLIENT_VERIFY=$1
    SetEnvIf X-Client-DN "(.*)" SSL_CLIENT_S_DN=$1

    PassengerEnabled On
    DocumentRoot /var/opt/lib/pe-puppetmaster/public/
    ErrorLog /var/log/pe-httpd/puppetmaster.error.log
    TransferLog /var/log/pe-httpd/puppetmaster.access.log
    <Directory /var/opt/lib/pe-puppetmaster/>
        Options None
        AllowOverride None
        Order allow,deny
        allow from all
    </Directory>
</VirtualHost>',
    notify => Service['pe-httpd'],
  }

  ## EXTRA: To make vagrant easier
  if ! defined(Service['pe-httpd']) {
    service { 'pe-httpd':
      ensure => running,
    }
  }
  file { '/etc/puppetlabs/puppet/autosign.conf':
    ensure  => file,
    content => "*\n",
  }
}

node /^nonca\d/ {
  ####################################################################

  ## First run (before manual steps)
  #class { 'pe_shared_ca':
  #  ca_server => false,
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
#  file_line { 'pe-httpd_crl':
#    path  => '/etc/puppetlabs/httpd/conf.d/puppetmaster.conf',
#    match => '    SSLCARevocationFile     /etc/puppetlabs/puppet/ssl/.*crl.pem',
#    line  => '    SSLCARevocationFile     /etc/puppetlabs/puppet/ssl/crl.pem',
#  }
#
#  ## Configure non-ssl on 18140
#  file { '/etc/puppetlabs/httpd/conf.d/puppetmaster-nossl.conf':
#    ensure  => file,
#    owner   => 'root',
#    group   => 'pe-puppet',
#    mode    => '0644',
#    content => 'Listen 18140
#<VirtualHost *:18140>
#    ServerAlias puppet puppet.puppetlabs.vm
#    SSLEngine off
#
#    SetEnvIf X-Client-Verify "(.*)" SSL_CLIENT_VERIFY=$1
#    SetEnvIf X-Client-DN "(.*)" SSL_CLIENT_S_DN=$1
#
#    PassengerEnabled On
#    DocumentRoot /var/opt/lib/pe-puppetmaster/public/
#    ErrorLog /var/log/pe-httpd/puppetmaster.error.log
#    TransferLog /var/log/pe-httpd/puppetmaster.access.log
#    <Directory /var/opt/lib/pe-puppetmaster/>
#        Options None
#        AllowOverride None
#        Order allow,deny
#        allow from all
#    </Directory>
#</VirtualHost>',
#    notify => Service['pe-httpd'],
#  }
#  if ! defined(Service['pe-httpd']) {
#    service { 'pe-httpd':
#      ensure => running,
#    }
#  }

  #vagrant extra
  if ! defined(Service['pe-puppet']) {
    service { 'pe-puppet':
      ensure => stopped,
    }
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
