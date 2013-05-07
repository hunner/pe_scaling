#!/bin/sh

export PATH=$PATH:/usr/local/bin

puppet resource service iptables ensure=stopped
puppet resource host master-ca-primary.puppetlabs.vm ensure=present ip=10.10.10.10
puppet resource host master-nonca1.puppetlabs.vm     ensure=present ip=10.10.10.11
puppet resource host master-nonca2.puppetlabs.vm     ensure=present ip=10.10.10.12
puppet resource host agent1.puppetlabs.vm            ensure=present ip=10.10.10.13
puppet resource host puppet.puppetlabs.vm            ensure=present ip=10.10.10.14 host_aliases=haproxy

if [[ ! -d /opt/puppet ]] ; then
    /vagrant/puppet-enterprise-2.8.1-el-6-x86_64/puppet-enterprise-installer -a /vagrant/answers/`hostname`
fi

/opt/puppet/bin/puppet resource package puppet ensure=absent
/opt/puppet/bin/puppet resource package facter ensure=absent

puppet apply /vagrant/manifests/site.pp --modulepath /vagrant/modules:/opt/puppet/share/puppet/modules
