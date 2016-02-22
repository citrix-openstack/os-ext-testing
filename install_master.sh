#!/usr/bin/env bash
set -eux

THIS_DIR=`pwd`
DATA_PATH=/root/os-ext-data

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
