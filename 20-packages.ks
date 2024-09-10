%packages --excludedocs
# from lorax examples
@core
kernel
kernel-modules
kernel-modules-extra
grub2-efi
grub2
shim
syslinux
dracut-config-generic
-dracut-config-rescue
dracut-network
tar
isomd5sum

postgresql
# Workaround until https://github.com/theforeman/foreman-packaging/pull/11221
ruby
ruby-devel
rubygems-devel
newt-devel

# required by lorax
dracut-live
# required by bootloader
centos-logos
memtest86+
biosdevname
vim-minimal

# Facter
rubygem-facter
ethtool
lldpad
net-tools
dmidecode
virt-what

# Foreman proxy
# Workaround until https://github.com/theforeman/foreman-packaging/pull/11221
# foreman-discovery-image-service
curl
wget
passwd
sudo
OpenIPMI
ipmitool
openssl
elfutils-libs

# Interactive discovery
# Workaround until https://github.com/theforeman/foreman-packaging/pull/11221
# foreman-discovery-image-service-tui
kexec-tools
kbd

# Debugging support
less
file

# SSH access
openssh-clients
openssh-server

# Starts all interfaces automatically for us
NetworkManager

# Used to update code at runtime
unzip

# Enable stripping
binutils

# For UEFI/Secureboot support
efibootmgr
grub2-efi
grub2-efi-x64
grub2-efi-x64-cdboot
shim
shim-x64

# Useful utilities for users who use FDI for image-based provisioning
grub2-tools
e2fsprogs
parted
mdadm
xfsprogs
e2fsprogs
bzip2
tcpdump

######################
# Packages to Remove #
######################
#
# Some ideas from:
#
# https://github.com/weldr/lorax/blob/rhel7-branch/share/runtime-cleanup.tmpl

%end
