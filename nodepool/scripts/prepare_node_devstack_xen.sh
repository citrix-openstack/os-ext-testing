#!/bin/bash
set -xe

./prepare_node_devstack.sh

# Install Xen and update the kernel
sudo apt-get -y install htop vim git pwgen xen-hypervisor-4.4

sudo mv /etc/default/grub{,.bak}
sudo tee /etc/default/grub << EOC
GRUB_DEFAULT=0
GRUB_TIMEOUT=30
GRUB_DISTRIBUTOR=\`lsb_release -i -s 2> /dev/null || echo Debian\`
GRUB_CMDLINE_LINUX_DEFAULT="debug loglevel=7"
GRUB_CMDLINE_LINUX=""
GRUB_TERMINAL=console
GRUB_DISABLE_LINUX_UUID="false"
EOC

sudo mv /etc/default/grub.d/xen.cfg{,.bak}
sudo tee /etc/default/grub.d/xen.cfg << EOC
echo "Including Xen overrides from /etc/default/grub.d/xen.cfg"
GRUB_CMDLINE_XEN="dom0_mem=7680M,max:7680M dom0_max_vcpus=4 max-console=vga"
GRUB_DEFAULT="Ubuntu GNU/Linux, with Xen hypervisor"
EOC

sudo update-grub

# Disable cloud-init - it doesn't work in dom0 Xen
for i in /etc/init/cloud-*; do echo manual | sudo tee ${i%.conf}.override; done

# Install Monty's config drive network setup (from https://review.openstack.org/#/c/154132/5)
# ./read-vendor-json/install.d/05-read-vendor-json
sudo cp read-vendor-json.py /usr/local/bin
sudo cp static-network-config /etc/init.d

# ./read-vendor-json/install.d/10-static-network-config
sudo tee /etc/init/write-network-interfaces.conf <<EOF
start on starting networking
task
exec /etc/init.d/static-network-config
EOF

# ./read-vendor-json/install.d/15-write-interfaces
sudo rm -rf /etc/network/interfaces.d
sudo tee /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback
EOF

# Create a swap file
sudo dd if=/dev/zero of=/swapfile bs=1024 count=524288
sudo chown root:root /swapfile
sudo chmod 0600 /swapfile
sudo mkswap /swapfile
echo "/swapfile	none	swap	sw	0	0" | sudo tee -a /etc/fstab

sync
sleep 5
