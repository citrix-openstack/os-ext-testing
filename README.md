Setting up the libvirt+xen CI
=============================

The instructions below were taken from http://docs.openstack.org/infra/openstackci/third_party_ci.html Feb 2016 which may have additional debugging suggestions if there are missing items

They depend on a secret credentials directory which currently only accessible by Citrix (os-ext-data).

Steps to reinstall
------------------

1. Log in to mycloud.rackspace.com using credentials from os-ext-data/single_node_ci_data.yaml - Search for 'username' and 'password' under the 'oscc_file_contents' setting
  * Create new Ubuntu 14.04 server (copy password), hostname 'jenkins-libvirt'
  * 7.5GB Compute v1 flavor
  * Enable monitoring and security updates
  * Save the password for use in step 2a
  * Add key from os-ext-data/xenproject_jenkins.pub with the name 'xenproject-nodepool'
2. Initial server setup:
  * Disable password authentication on jenkins server
    * ssh-copy-id to copy a key to the server
    * edit /etc/sshd_config to set "PermitRootLogin without-password"
    * service ssh restart
  * Add a 8GB swap file:
    * fallocate -l 8G /swapfile; chmod 600 /swapfile; mkswap /swapfile; swapon /swapfile
    * echo "/swapfile   none    swap    sw    0   0" >> /etc/fstab
3. Copy the secret credentials dir to /root/os-ext-data
4. Clone this repo:
  * apt-get install git
  * git clone https://github.com/citrix-openstack/os-ext-testing.git
  * cd os-ext-testing
5. Run install_master.sh to do the main part of the installation
6. The jobs need an additional plugin in Jenkins to generate correctly, so:
  * Install Post-Build Script jenkins plugin (including restarting Jenkins)
  * Regenerate jenkins jobs: jenkins-jobs update --delete-old /etc/jenkins_jobs/config
  * Enable HTML: Manage Jenkins -> Configure Global Security -> Markup Formatter -> Raw HTML
7. Start the CI processes
  * service zuul start; service zuul-merger start
  * Wait for a bit, check there are 3 zuul processes (1 merger, 2 servers)
  * service nodepool start
  * Wait for a bit (5m); check an image is being built (su - nodepool; nodepool image-list)
  * Wait for a lot (1h?); check a node is built (su - nodepool; nodepool list)
  * Check http://<ip> and http://<ip>:8080 to check that zuul + jenkins (respectively) are running
  * Enable gearman and ZMQ in Jenkins (Manage Jenkins --> Configure System) 
8. Secure jenkins - instructions at end of http://docs.openstack.org/infra/openstackci/third_party_ci.html
9. Set up monitoring checks https://intelligence.rackspace.com/
10. The CI will be set up to run jobs on openstack-dev/ci-sandbox.  Check that jobs posted there will pass the CI
  * Once jobs pass on the sandbox, enable dsvm-tempest-xen in the "silent" job (rather than check) by editing project-config/zuul/layout.yaml:

  ```
  projects:
    - name: openstack-dev/ci-sandbox
       check:
         - dsvm-tempest-xen
    - name: openstack/nova
       silent
         - dsvm-tempest-xen
  ```
  * Change the email address in the silent job from openstack-ci@xenproject.org to one you can monitor
  * sudo puppet apply --verbose /etc/puppet/manifests/site.pp
  * Verify that the silent jobs are passing (through the emails)
  * Modify the silent job on openstack/nova to be a check job
  * sudo puppet apply --verbose /etc/puppet/manifests/site.pp
