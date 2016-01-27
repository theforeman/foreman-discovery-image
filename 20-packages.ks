%packages --excludedocs
bash
kernel
grub2
grub2-tools
e2fsprogs
passwd
policycoreutils
chkconfig
rootfiles
yum
vim-minimal
acpid
tftp
lldpad
isomd5sum

# Dracut missing deps (https://bugzilla.redhat.com/show_bug.cgi?id=1285810)
tar
gzip

# Facter
facter
ethtool
net-tools
dmidecode
virt-what

# Foreman
sudo
OpenIPMI
OpenIPMI-tools
openssl
foreman-proxy
rubygem-smart_proxy_discovery_image

# Interactive discovery
kexec-tools
rubygem-newt

# Debugging support
less
file

# Only needed because livecd-tools runs /usr/bin/firewall-offline-cmd
# unconditionally; patch submitted upstream. Remove once released version
# with it is available
firewalld

# SSH access
openssh-clients
openssh-server

# Starts all interfaces automatically for us
NetworkManager
uuid

# Used to update code at runtime
unzip

# Enable stripping
binutils

# For UEFI/Secureboot support
grub2-efi
efibootmgr
shim

# Device writing
nmap-ncat
lzop
udpcast

#
# Packages to Remove
#
-prelink
-setserial
-ed
-authconfig
-wireless-tools

# Remove the kbd bits
-kbd
-usermode

# file system stuff
-dmraid
-mdadm
-lvm2
-e2fsprogs
-e2fsprogs-libs

# grub
-freetype
-grubby
-os-prober

# selinux toolchain of policycoreutils, libsemanage, ustr
-policycoreutils
-checkpolicy
-selinux-policy*
-libselinux-python
-libselinux

# Things it would be nice to loose
-fedora-logos
-fedora-release-notes
%end
