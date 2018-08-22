#!/bin/bash
# vim: sw=2:ts=2:et
set -x
export repoowner=${1:-theforeman}
export branch=${2:-master}
export proxy_repo=${3:-nightly}
NAME=foreman-discovery-image

# give the VM some time to finish booting and network configuration
sleep 30
ping -c1 8.8.8.8 2>&1 >/dev/null && echo NET OK || echo NET FAILURE
yum -y install livecd-tools appliance-tools-minimizer \
  hardlink git wget pykickstart isomd5sum syslinux
yum -y install grub2-efi shim || yum -y install grub2-efi-x64 grub2-efi-x64-cdboot shim-x64 || true

# build plugin
pushd /root
SELINUXMODE=$(getenforce)
setenforce 1

[ -d $NAME ] || git clone https://github.com/$repoowner/$NAME.git -b $branch
pushd $NAME
git pull

./build-livecd fdi-centos7.ks $proxy_repo && sudo ./build-livecd-root
aux/remaster/discovery-remaster
ls fdi-image*tar -lah

popd
setenforce $SELINUXMODE
