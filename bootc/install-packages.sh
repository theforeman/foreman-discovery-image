#!/bin/bash
# Runs inside the container build; invoked by the Containerfile.
set -euo pipefail
. /etc/os-release
cat > /etc/yum.repos.d/fdi-foreman.repo <<REPOS
[fdi-foreman]
name=Foreman ${FOREMAN_VERSION}
baseurl=https://yum.theforeman.org/releases/${FOREMAN_VERSION}/el${VERSION_ID}/\$basearch/
enabled=1
gpgcheck=0
[fdi-foreman-plugins]
name=Foreman plugins ${FOREMAN_VERSION}
baseurl=https://yum.theforeman.org/plugins/${FOREMAN_VERSION}/el${VERSION_ID}/\$basearch/
enabled=1
gpgcheck=0
REPOS
dnf -y --setopt=tsflags=nodocs upgrade
mapfile -t packages < <(sed '/^#/d; /^[[:space:]]*$/d' /tmp/fdi-packages.txt)
read -r -a extra_packages <<< "${EXTRA_PACKAGES}"
dnf -y --setopt=tsflags=nodocs install "${packages[@]}" "${extra_packages[@]}"
dnf clean all
rm -f /tmp/fdi-packages.txt /tmp/fdi-install-packages.sh
