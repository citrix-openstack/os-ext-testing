#!/usr/bin/env bash
set -eux

THIS_DIR=`pwd`
DATA_PATH=/root/os-ext-data

# Steps to reinstall:
# 1) Log in to mycloud.rackspace.com using credentials from os-ext-data/xenlibvirt-nodepool
# 1a) Create new Ubuntu 14.04 server (copy password), hostname 'jenkins-libvirt'
#     7.5GB Compute v1 flavor
#     Enable monitoring and security updates
# 1b) Save the password for use in step 2a
# 1c) Add key from os-ext-data/xenproject_jenkins.pub with the name 'xenproject-nodepool'
# 2) Disable password authentication on jenkins server
# 2a) ssh-copy-id to copy a key to the server
# 2b) edit /etc/sshd_config to set "PermitRootLogin without-password"
# 2c) service ssh restart
# 3) Copy the secret credentials dir (http://hg.uk.xensource.com/openstack/infrastructure.hg/os-ext-data) to /root
# 4) Clone this repo:
# 4a) apt-get install git
# 4b) git clone https://github.com/citrix-openstack/os-ext-testing.git
# 4c) cd os-ext-testing; git checkout common_ci
# 5) Run below commands (or just this script) to do the 'standard' install
# 6) The jobs need an additional plugin in Jenkins to generate correctly, so:
# 6a) Install Post-Build Script jenkins plugin (including restarting Jenkins)
# 6b) Regenerate jenkins jobs: jenkins-jobs update --delete-old /etc/jenkins_jobs/config
# ?) Set up monitoring checks https://intelligence.rackspace.com/cloud/entities/enWCIYVVnt

# Copied from the following URL Feb 2016
# http://docs.openstack.org/infra/openstackci/third_party_ci.html

# Install puppet
[ -e install_puppet.sh ] && rm install_puppet.sh
wget https://git.openstack.org/cgit/openstack-infra/system-config/plain/install_puppet.sh
bash install_puppet.sh

# Install puppet modules to /etc/puppet/modules
[ -e system-config ] && rm -rf system-config
git clone https://git.openstack.org/openstack-infra/system-config
cd system-config
./install_modules.sh

# Setup the site we're deploying
cp /etc/puppet/modules/openstackci/contrib/single_node_ci_site.pp /etc/puppet/manifests/site.pp

# And the secret credentials store
cp /etc/puppet/modules/openstackci/contrib/hiera.yaml /etc/puppet

# Verify that our config file matches the latest template file
# If this check fails, copy the new template to os-ext-data and create a new secrets file
diff -q /root/os-ext-data/single_node_ci_data_orig.yaml /etc/puppet/modules/openstackci/contrib/single_node_ci_data.yaml
# Since the template hasn't changed, just use the existing secrets
cp /root/os-ext-data/single_node_ci_data.yaml /etc/puppet/environments/common.yaml

# Add 'jenkins' to the hostname so Apache is happy
sed -i -e 's/^\(127\.0\.0\.1.*\)$/\1 jenkins/' /etc/hosts

sudo puppet apply --verbose /etc/puppet/manifests/site.pp

