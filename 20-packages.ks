%packages --excludedocs --nobase
bash
kernel
grub2
e2fsprogs
passwd
policycoreutils
chkconfig
rootfiles
yum
vim-minimal
acpid
tftp

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
foreman-proxy

# Debugging support
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

# Used to update code at runtime
unzip

# Enable stripping
binutils

#
# Packages to Remove
#
-prelink
-setserial
-ed
-tar
-authconfig
-wireless-tools

# Remove the kbd bits
-kbd
-usermode

# file system stuff
-kpartx
-dmraid
-mdadm
-lvm2
-e2fsprogs
-e2fsprogs-libs

# grub
-freetype
-grub2
-grub2-tools
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
# EL
#generic-logos
-fedora-release-notes
%end
