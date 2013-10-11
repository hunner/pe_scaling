node 'lb' {
  ## Special vagrant stuff
  file { '/etc/puppetlabs/puppet/ssl/crl.pem':
    source => '/vagrant/files/ssl/crl.pem',
    before => Class['apache'],
  }
  file { '/etc/puppetlabs/puppet/ssl/certs/ca.pem':
    source => '/vagrant/files/ssl/certs/ca.pem',
    before => Class['apache'],
  }
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
  class { 'apache::mod::proxy':
    allow_from => '10.3.0',
  }

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
    ssl_ca          => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
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
    ipaddresses       => '10.3.0.18',
    ports             => '443',
    options           => [
      'check',
      'downinter 500',
    ],
  }
  haproxy::balancermember { 'console console2.puppetlabs.vm':
    listening_service => 'console00',
    ipaddresses       => '10.3.0.19',
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
    ipaddresses       => '10.3.0.14',
    ports             => '61613',
    options           => 'check',
  }
  haproxy::balancermember { 'activemq nonca2.puppetlabs.vm':
    listening_service => 'activemq00',
    ipaddresses       => '10.3.0.15',
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
    ipaddresses       => '10.3.0.16',
    ports             => '8081',
    options           => [
      'check',
      'downinter 500',
    ],
  }
  haproxy::balancermember { 'puppetdb puppetdb2.puppetlabs.vm':
    listening_service => 'puppetdb00',
    ipaddresses       => '10.3.0.17',
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
  package { 'pgdg-redhat92-9.2-7.noarch':
    ensure   => present,
    source   => 'http://yum.postgresql.org/9.2/redhat/rhel-6-x86_64/pgdg-redhat92-9.2-7.noarch.rpm',
    provider => 'rpm',
    before   => Class['postgresql'],
  }

  class { 'postgresql':
    version => '9.2',
    bindir  => '/usr/pgsql-9.2/bin',
    before  => Class['postgresql::server'],
  }

  class { 'postgresql::server':
    package_name                   => 'postgresql92-server',
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

# Used to make certs for other nodes with dns_alt_names
define make_cert {
  exec { "generate ${name} cert":
    command   => "/opt/puppet/bin/puppet certificate generate --ca-location local ${name}.puppetlabs.vm --dns-alt-names ${name},puppet,puppet.puppetlabs.vm",
    creates   => "/etc/puppetlabs/puppet/ssl/certificate_requests/${name}.puppetlabs.vm.pem",
    logoutput => 'on_failure',
    before    => Exec["sign ${name} cert"],
  }
  exec { "sign ${name} cert":
    command   => "/opt/puppet/bin/puppet cert sign ${name}.puppetlabs.vm --allow-dns-alt-names",
    creates   => "/etc/puppetlabs/puppet/ssl/ca/signed/${name}.puppetlabs.vm.pem",
    logoutput => 'on_failure',
  }
  file { "/vagrant/files/ssl/certs/${name}.puppetlabs.vm.pem":
    source  => "/etc/puppetlabs/puppet/ssl/ca/signed/${name}.puppetlabs.vm.pem",
    require => Exec["sign ${name} cert"],
  }
  file { "/vagrant/files/ssl/public_keys/${name}.puppetlabs.vm.pem":
    source  => "/etc/puppetlabs/puppet/ssl/public_keys/${name}.puppetlabs.vm.pem",
    require => Exec["sign ${name} cert"],
  }
  file { "/vagrant/files/ssl/private_keys/${name}.puppetlabs.vm.pem":
    source  => "/etc/puppetlabs/puppet/ssl/private_keys/${name}.puppetlabs.vm.pem",
    require => Exec["sign ${name} cert"],
  }
}

node /^ca\d/ {
  ## Workaround for https://jira-private.puppetlabs.com/browse/PE-1721
  file { $settings::reportdir:
    ensure => directory,
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0750',
  }


  if $::clientcert == 'ca1.puppetlabs.vm' {
    make_cert { ['puppetdb1','puppetdb2','lb']: }

    class { 'pe_shared_ca::update_module': }
    file { [
      '/vagrant/files',
      '/vagrant/files/ssl',
      '/vagrant/files/ssl/certs',
      '/vagrant/files/ssl/public_keys',
      '/vagrant/files/ssl/private_keys',
    ]:
      ensure => directory,
    }
    file { '/vagrant/files/ssl/crl.pem':
      source => '/etc/puppetlabs/puppet/ssl/crl.pem',
    }
    file { '/vagrant/files/ssl/certs/ca.pem':
      source => '/etc/puppetlabs/puppet/ssl/certs/ca.pem',
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
  ## Workaround for https://jira-private.puppetlabs.com/browse/PE-1721
  file { $settings::reportdir:
    ensure => directory,
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0750',
  }

  ####################################################################

  ## First run (before manual steps)
  #class { 'pe_shared_ca':
  #  ca_server => false,
  #  before    => Exec['stop'],
  #}
  #ini_setting { 'puppet.conf main dns_alt_names':
  #  path    => '/etc/puppetlabs/puppet/puppet.conf',
  #  section => 'main',
  #  setting => 'dns_alt_names',
  #  value   => "puppet,puppet.${::domain},${::hostname},${::fqdn}",
  #  before  => Exec['stop'],
  #}
  #exec { 'stop':
  #  command => '/bin/false',
  #}

  # Manual steps:
  # 1. On non-CA: Run `puppet agent -t` to generate new cert with dns alt names on DG
  # 2. On DG:     Run `puppet cert sign ${non_ca_master_fqdn} --allow-dns-alt-names`
  # 3. On non-CA: Run `puppet agent -t` to retrieve signed cert.

  ## Second run (after signing cert)
#  file { '/etc/puppetlabs/puppet/ssl/crl.pem':
#    source => '/vagrant/files/ssl/crl.pem',
#    owner  => 'pe-puppet',
#    group  => 'pe-puppet',
#    before => File_line['pe-httpd_crl'],
#  }
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

  ####################################################################

  #vagrant extra
  if ! defined(Service['pe-puppet']) {
    service { 'pe-puppet':
      ensure => stopped,
    }
  }
}

node /puppetdb\d/ {
  ## Special vagrant stuff
  file { "/etc/puppetlabs/puppet/ssl/certs/${::clientcert}.pem":
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0644',
    source => "/vagrant/files/ssl/certs/${::clientcert}.pem",
    notify => Exec['/opt/puppet/sbin/puppetdb-ssl-setup -f'],
  }
  file { "/etc/puppetlabs/puppet/ssl/public_keys/${::clientcert}.pem":
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0644',
    source => "/vagrant/files/ssl/public_keys/${::clientcert}.pem",
    notify => Exec['/opt/puppet/sbin/puppetdb-ssl-setup -f'],
  }
  file { "/etc/puppetlabs/puppet/ssl/private_keys/${::clientcert}.pem":
    owner  => 'pe-puppet',
    group  => 'pe-puppet',
    mode   => '0600',
    source => "/vagrant/files/ssl/private_keys/${::clientcert}.pem",
    notify => Exec['/opt/puppet/sbin/puppetdb-ssl-setup -f'],
  }
  file_line { 'allow nonca1':
    ensure => present,
    path   => '/etc/puppetlabs/puppetdb/certificate-whitelist',
    line   => 'nonca1.puppetlabs.vm',
  }
  file_line { 'allow nonca2':
    ensure => present,
    path   => '/etc/puppetlabs/puppetdb/certificate-whitelist',
    line   => 'nonca2.puppetlabs.vm',
  }
  exec { '/opt/puppet/sbin/puppetdb-ssl-setup -f':
    refreshonly => true,
    notify      => Service['pe-puppetdb'],
  }
  if ! defined(Service['pe-puppetdb']) {
    service { 'pe-puppetdb':
      ensure => running,
    }
  }
}

node /^console\d/ {
  if $::clientcert == 'console1.puppetlabs.vm' {
    $rake = '/opt/puppet/bin/rake -f /opt/puppet/share/puppet-dashboard/Rakefile RAILS_ENV=production'
    exec { 'Configure puppet nodes':
      command => "${rake} \
         'node:add[lb.puppetlabs.vm,mcollective,,skip]' \
         'node:add[postgres.puppetlabs.vm,mcollective,,skip]' \
         'node:add[ca1.puppetlabs.vm,puppet_master\,mcollective,,skip]' \
         'node:add[ca2.puppetlabs.vm,puppet_master\,mcollective,,skip]' \
         'node:add[nonca1.puppetlabs.vm,puppet_master\,mcollective,pe_puppetdb::master,skip]' \
         'node:add[nonca2.puppetlabs.vm,puppet_master\,mcollective,pe_puppetdb::master,skip]' \
         'node:add[puppetdb1.puppetlabs.vm,puppet_puppetdb\,mcollective,,skip]' \
         'node:add[puppetdb2.puppetlabs.vm,puppet_puppetdb\,mcollective,,skip]' \
         'node:add[console1.puppetlabs.vm,puppet_console\,mcollective,,skip]' \
         'node:add[console2.puppetlabs.vm,puppet_console\,mcollective,,skip]' \
         'node:variables[nonca1.puppetlabs.vm,activemq_brokers=nonca2]' \
         'node:variables[nonca2.puppetlabs.vm,activemq_brokers=nonca1]' \
         'node:addclass[puppetdb1.puppetlabs.vm,pe_puppetdb]' \
         'node:addclass[puppetdb2.puppetlabs.vm,pe_puppetdb]' \
         'node:addclassparam[puppetdb1.puppetlabs.vm,pe_puppetdb,database_host,postgres.puppetlabs.vm]' \
         'node:addclassparam[puppetdb1.puppetlabs.vm,pe_puppetdb,manage_database,false]' \
         'node:addclassparam[puppetdb1.puppetlabs.vm,pe_puppetdb,ssl_listen_address,puppetdb1.puppetlabs.vm]' \
         'node:addclassparam[puppetdb2.puppetlabs.vm,pe_puppetdb,database_host,postgres.puppetlabs.vm]' \
         'node:addclassparam[puppetdb2.puppetlabs.vm,pe_puppetdb,manage_database,false]' \
         'node:addclassparam[puppetdb2.puppetlabs.vm,pe_puppetdb,ssl_listen_address,puppetdb2.puppetlabs.vm]' \
         'node:addclassparam[nonca1.puppetlabs.vm,pe_puppetdb::master,manage_config,true]' \
         'node:addclassparam[nonca1.puppetlabs.vm,pe_puppetdb::master,manage_report_processor,true]' \
         'node:addclassparam[nonca1.puppetlabs.vm,pe_puppetdb::master,manage_routes,true]' \
         'node:addclassparam[nonca1.puppetlabs.vm,pe_puppetdb::master,manage_storeconfigs,true]' \
         'node:addclassparam[nonca1.puppetlabs.vm,pe_puppetdb::master,puppetdb_server,puppet]' \
         'node:addclassparam[nonca2.puppetlabs.vm,pe_puppetdb::master,manage_config,true]' \
         'node:addclassparam[nonca2.puppetlabs.vm,pe_puppetdb::master,manage_report_processor,true]' \
         'node:addclassparam[nonca2.puppetlabs.vm,pe_puppetdb::master,manage_routes,true]' \
         'node:addclassparam[nonca2.puppetlabs.vm,pe_puppetdb::master,manage_storeconfigs,true]' \
         'node:addclassparam[nonca2.puppetlabs.vm,pe_puppetdb::master,puppetdb_server,puppet]' \
         'node:del[puppet]'
      ",
      onlyif  => "${rake} node:list[^puppet$] | grep puppet",
    }
  }
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
