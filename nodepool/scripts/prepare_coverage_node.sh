#!/bin/bash -ex
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y python-pip git postgresql libpq-dev python-dev build-essential postgresql-server-dev-all default-jre openssl python3-dev tox
#DEBIAN_FRONTEND=noninteractive apt-get install -y python-pip python-dev openjdk-9-jre tox
cat > /etc/resolv.conf <<EOF
# Dynamic resolv.conf(5) file for glibc resolver(3) generated by resolvconf(
#     DO NOT EDIT THIS FILE BY HAND -- YOUR CHANGES WILL BE OVERWRITTEN
nameserver 10.71.212.9
nameserver 10.71.212.10
EOF

# Prepare for access via jenkins
# Consider to use puppet to do the configuration?
mkdir -p /home/jenkins/.ssh
echo "ssh-rsa ${NODEPOOL_SSH_KEY}" >> /home/jenkins/.ssh/authorized_keys
chown -R jenkins /home/jenkins
cat >/etc/sudoers.d/jenkins-sudo <<EOF
jenkins ALL=(ALL) NOPASSWD:ALL
EOF
chmod 440 /etc/sudoers.d/jenkins-sudo

cat >/etc/rc.local <<EOF
#!/bin/sh -e
set -x
echo "127.0.0.1 \$(hostname)" >>/etc/hosts
touch /var/run/coverage_node.ready
exit 0
EOF

sync
sleep 5
sync
#sudo halt -p &

exit 0
