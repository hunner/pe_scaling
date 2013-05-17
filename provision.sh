#!/bin/sh

export PATH=$PATH:/usr/local/bin

puppet resource service iptables ensure=stopped

if ! grep 'puppet.puppetlabs.vm' /etc/hosts ; then
    cat >> /etc/hosts <<EOF
10.2.10.10 dg.puppetlabs.vm       dg
10.2.10.11 haproxy.puppetlabs.vm  haproxy
10.2.10.12 nonca1.puppetlabs.vm   nonca1
10.2.10.13 nonca2.puppetlabs.vm   nonca2
10.2.10.14 mysql.puppetlabs.vm    mysql
10.2.10.15 console1.puppetlabs.vm console1
10.2.10.16 console2.puppetlabs.vm console2
10.2.10.17 agent1.puppetlabs.vm   agent1
10.2.10.11 puppet.puppetlabs.vm   puppet
EOF
fi

if [ $HOSTNAME = 'console1.puppetlabs.vm' -o $HOSTNAME = 'console2.puppetlabs.vm' ] ; then
  puppet resource package mysql ensure=present
fi

if [ ! -d /opt/puppet ] ; then
    /vagrant/pe/puppet-enterprise-installer -D -a /vagrant/answers/`hostname -f`
fi

/opt/puppet/bin/puppet resource package puppet ensure=absent
/opt/puppet/bin/puppet resource package facter ensure=absent

/opt/puppet/bin/puppet apply /vagrant/manifests/site.pp --show_diff --modulepath /vagrant/modules:/opt/puppet/share/puppet/modules
