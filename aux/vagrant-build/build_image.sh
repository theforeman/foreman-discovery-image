#!/bin/bash
# vim: sw=2:ts=2:et
set -x
export repoowner=${1:-theforeman}
export branch=${2:-master}
export proxy_repo=${3:-http://yum.theforeman.org/nightly/el7/x86_64/}
NAME=foreman-discovery-image

# give the VM some time to finish booting and network configuration
ping -c1 8.8.8.8 2>&1 >/dev/null && echo OK || echo FAIL
yum -y install livecd-tools appliance-tools-minimizer fedora-packager \
  python-devel rpm-build createrepo selinux-policy-doc checkpolicy \
  selinux-policy-devel autoconf automake python-mock python-lockfile \
  python-nose git-review qemu-kvm hardlink git wget pykickstart

# build plugin
pushd /root
SELINUXMODE=$(getenforce)
setenforce 1

[ -d $NAME ] || git clone --depth 1 https://github.com/$repoowner/$NAME.git -b $branch
pushd $NAME
git pull

./build-livecd fdi-centos7.ks && sudo ./build-livecd-root
ls fdi-image*tar -lah

popd
setenforce $SELINUXMODE
