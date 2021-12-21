#!/bin/bash
# vim: sw=2:ts=2:et
set -x
export repoowner=${1:-theforeman}
export branch=${2:-master}
export proxy_repo=${3:-nightly}
NAME=foreman-discovery-image

echo "Short sleep to allow things to settle down"
sleep 10
ping -c1 8.8.8.8 2>&1 >/dev/null && echo NET OK || echo NET FAILURE

sudo dnf -y install lorax qemu-kvm anaconda pykickstart git wget

# some versions of lorax might require SELinux turned off
#SELINUXMODE=$(getenforce)
#sudo setenforce 1

[ -d $NAME ] || git clone https://github.com/$repoowner/$NAME.git -b $branch
pushd $NAME
git pull

./build-livecd fdi-centos8.ks $proxy_repo && sudo ./build-livecd-root
ls -lah

#sudo setenforce $SELINUXMODE
