#!/bin/sh

export PATH=$PATH:/usr/local/bin

# Stop iptables
if service iptables status > /dev/null ; then
  echo 'Disabling iptables'
  service iptables stop
  chkconfig iptables off
fi

# Set up hosts
if ! grep 'puppet.puppetlabs.vm' /etc/hosts > /dev/null ; then
  echo 'Configuring /etc/hosts'
  cat >> /etc/hosts <<EOF
10.2.10.10 haproxy.puppetlabs.vm   haproxy
10.2.10.11 postgres.puppetlabs.vm  postgres
10.2.10.12 nonca1.puppetlabs.vm    nonca1
10.2.10.13 nonca2.puppetlabs.vm    nonca2
10.2.10.14 puppetdb1.puppetlabs.vm puppetdb1
10.2.10.15 puppetdb2.puppetlabs.vm puppetdb2
10.2.10.16 console1.puppetlabs.vm  console1
10.2.10.17 console2.puppetlabs.vm  console2
10.2.10.18 agent1.puppetlabs.vm    agent1
10.2.10.10 puppet.puppetlabs.vm    puppet
EOF
fi

if [ ! -d /opt/puppet ] ; then
  echo 'Installing PE'
  /vagrant/pe/puppet-enterprise-installer -D -a /vagrant/answers/`hostname -f`
fi

if [ $(hostname -s) = 'nonca1' -o $(hostname -s) = 'nonca2' ] ; then
  if ! grep 'import' /etc/puppetlabs/puppet/manifests/site.pp > /dev/null ; then
    echo 'Catting to site.pp'
    echo 'import "/vagrant/manifests/site.pp"' >> /etc/puppetlabs/puppet/manifests/site.pp
  fi
  if [ $(ls /etc/puppetlabs/puppet/modules|wc -l) -eq 0 ] ; then
    echo 'Symlinking modules'
    rmdir /etc/puppetlabs/puppet/modules
    ln -s /vagrant/modules /etc/puppetlabs/puppet/modules
  fi
fi

if [ $(hostname -s) = 'haproxy' -o $(hostname -s) = 'postgres' ] ; then
  /opt/puppet/bin/puppet apply --modulepath /vagrant/modules:/opt/puppet/share/puppet/modules /vagrant/manifests/site.pp
#else
  #/opt/puppet/bin/puppet agent -t && exit 0
fi
