#!/bin/bash
# vim: sw=2:ts=2:et
set -x
export repoowner=${1:-theforeman}
export branch=${2:-master}
export proxy_repo=${3:-nightly}
KERNEL_CMDLINE="nomodeset nokaslr"
NAME=foreman-discovery-image

echo "Short sleep to allow things to settle down"
sleep 10
ping -c1 8.8.8.8 2>&1 >/dev/null && echo NET OK || echo NET FAILURE
sudo setenforce 0

# There are several options with lorax. Recommended is building from ISO in
# qemu, this requires nested virtualization and it is extremely slow on CI.
# Building in mock did not work at all, therefore building directly on the host
# VM is the approach.

sudo dnf -y install pykickstart git wget lorax anaconda

[ -d $NAME ] || git clone https://github.com/$repoowner/$NAME.git -b $branch
pushd $NAME
git pull

version=$(git describe --abbrev=0 --tags)

./build-kickstart fdi-stream9.ks $proxy_repo && sudo ./build-livecd-root "$version" . "$KERNEL_CMDLINE" novirt

find .
popd
