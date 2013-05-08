#!/bin/sh

if [ -z "$1" -o -z "$2" ] ; then
    echo "PE version and platform arguments required"
    exit 1
else
    peversion=$1
    peplatform=$2
fi

if [ $peplatform == 'debian' ] ; then
    if ! egrep '^en_US.UTF-8 UTF-8$' /etc/locale.gen ; then
        echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
        locale-gen
    fi
fi

export PATH=$PATH:/usr/local/bin

if [ $peplatform == 'centos' ] ; then
    puppet resource service iptables ensure=stopped
fi

puppet resource host master-ca1.puppetlabs.vm    ensure=present ip=10.10.10.10 host_aliases=master-ca1
puppet resource host master-nonca1.puppetlabs.vm ensure=present ip=10.10.10.11 host_aliases=master-nonca1
puppet resource host master-nonca2.puppetlabs.vm ensure=present ip=10.10.10.12 host_aliases=master-nonca2
puppet resource host haproxy.puppetlabs.vm       ensure=present ip=10.10.10.13 host_aliases=puppet.puppetlabs.vm
puppet resource host agent1.puppetlabs.vm        ensure=present ip=10.10.10.14 host_aliases=agent1

if [ ! -d /opt/puppet ] ; then
    /vagrant/pe-${peversion}-${peplatform}/puppet-enterprise-installer -D -a /vagrant/answers-${peversion}-${peplatform}/`hostname -f`
fi

/opt/puppet/bin/puppet resource package puppet ensure=absent
/opt/puppet/bin/puppet resource package facter ensure=absent

/opt/puppet/bin/puppet apply /vagrant/manifests/site.pp --modulepath /vagrant/modules:/opt/puppet/share/puppet/modules
