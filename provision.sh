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
10.2.10.10 dg.puppetlabs.vm        dg
10.2.10.11 haproxy.puppetlabs.vm   haproxy
10.2.10.12 postgres.puppetlabs.vm  postgres
10.2.10.13 puppetdb1.puppetlabs.vm puppetdb1
10.2.10.14 puppetdb2.puppetlabs.vm puppetdb2
10.2.10.15 console1.puppetlabs.vm  console1
10.2.10.16 console2.puppetlabs.vm  console2
10.2.10.17 nonca1.puppetlabs.vm    nonca1
10.2.10.18 nonca2.puppetlabs.vm    nonca2
10.2.10.19 agent1.puppetlabs.vm    agent1
10.2.10.11 puppet.puppetlabs.vm    puppet
EOF
fi

## Install mysql client on console boxes
#if [ $HOSTNAME = 'console1.puppetlabs.vm' -o $HOSTNAME = 'console2.puppetlabs.vm' ] ; then
#  yum install mysql
#fi

if [ ! -d /opt/puppet ] ; then
  echo 'Installing PE'
  /vagrant/pe/puppet-enterprise-installer -D -a /vagrant/answers/`hostname -f`
fi

if [ $(hostname) = 'dg.puppetlabs.vm' ] ; then
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

/opt/puppet/bin/puppet agent -t && exit 0
#/opt/puppet/bin/puppet apply /vagrant/manifests/site.pp --show_diff --modulepath /vagrant/modules:/opt/puppet/share/puppet/modules
