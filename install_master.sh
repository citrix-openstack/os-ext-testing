#!/usr/bin/env bash
set -eux

THIS_DIR=`pwd`
DATA_PATH=/root/os-ext-data

# This script and guide was taken from
# http://docs.openstack.org/infra/openstackci/third_party_ci.html Feb
# 2016 which may have additional debugging suggestions if there are
# missing items

# Steps to reinstall:
# 1) Log in to mycloud.rackspace.com using credentials from os-ext-data/single_node_ci_data.yaml
#    Search for 'username' and 'password' under the 'oscc_file_contents' setting
# -- Create new Ubuntu 14.04 server (copy password), hostname 'jenkins-libvirt'
#     7.5GB Compute v1 flavor
#     Enable monitoring and security updates
# -- Save the password for use in step 2a
# -- Add key from os-ext-data/xenproject_jenkins.pub with the name 'xenproject-nodepool'
# 2) Initial server setup:
# -- Disable password authentication on jenkins server
# ---- ssh-copy-id to copy a key to the server
# ---- edit /etc/sshd_config to set "PermitRootLogin without-password"
# ---- service ssh restart
# -- Add a 8GB swap file:
# ---- fallocate -l 8G /swapfile; chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile
# ---- echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
# 3) Copy the secret credentials dir (http://hg.uk.xensource.com/openstack/infrastructure.hg/os-ext-data) to /root/os-ext-data
# 4) Clone this repo:
# -- apt-get install git
# -- git clone https://github.com/bobball/os-ext-testing.git
# -- cd os-ext-testing
# 5) Run below commands (or just this script) to do the 'standard' install
# 6) The jobs need an additional plugin in Jenkins to generate correctly, so:
# -- Install Post-Build Script jenkins plugin (including restarting Jenkins)
# -- Regenerate jenkins jobs: jenkins-jobs update --delete-old /etc/jenkins_jobs/config
# -- Enable HTML: Manage Jenkins -> Configure Global Security -> Markup Formatter -> Raw HTML
# 7) Start processes
# -- service zuul start; service zuul-merger start
# -- Wait for a bit, check there are 3 zuul processes (1 merger, 2 servers)
# -- service nodepool start
# -- Wait for a bit (5m); check an image is being built (su - nodepool; nodepool image-list)
# -- Wait for a lot (1h?); check a node is built (su - nodepool; nodepool list)
# -- Check http://<ip> and http://<ip>:8080 to check that zuul + jenkins (respectively) are running
# -- Enable gearman and ZMQ in Jenkins (Manage Jenkins --> Configure System) 
# 8) Secure jenkins - instructions at end of http://docs.openstack.org/infra/openstackci/third_party_ci.html
# 9) Set up monitoring checks https://intelligence.rackspace.com/
# 10) The CI will be set up to run jobs on openstack-dev/ci-sandbox.  Check that jobs posted there will pass the CI
# -- Once jobs pass on the sandbox, enable dsvm-tempest-xen in the "silent" job (rather than check) by
# ---- Editing project-config/zuul/layout.yaml:
# projects:
#   - name: openstack-dev/ci-sandbox
#     check:
#       - dsvm-tempest-xen
#
#   - name: openstack/nova
#     silent
#       - dsvm-tempest-xen
# ---- Change the email address in the silent job from openstack-ci@xenproject.org to one you can monitor
# ---- sudo puppet apply --verbose /etc/puppet/manifests/site.pp
# ---- Verify that the silent jobs are passing (through the emails)
# ---- Modify the silent job on openstack/nova to be a check job
# ---- sudo puppet apply --verbose /etc/puppet/manifests/site.pp


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

# Copy the osci config file (which includes the swift API key) to the
# nodepool-scripts directory so it will be added to nodes.
cp /root/os-ext-data/osci.config /etc/project-config/nodepool/scripts
# Need to re-run puppet as the first invocation will clone project-config using git.
sudo puppet apply --verbose /etc/puppet/manifests/site.pp
