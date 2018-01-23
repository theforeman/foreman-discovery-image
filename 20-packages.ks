%packages --excludedocs
bash
kernel
biosdevname
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

# Foreman proxy
sudo
OpenIPMI
OpenIPMI-tools
openssl
foreman-proxy
rubygem-smart_proxy_discovery_image

# Interactive discovery
kexec-tools
rubygem-newt
rubygem-fast_gettext
kbd

# Debugging support
less
file
tcpdump

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
efibootmgr
grub2-efi
shim
# These were renamed and split in EL 7.4+
grub2-efi-x64
grub2-efi-x64-cdboot
shim-x64

# tools that enable the image installer plugin
parted
mdadm
xfsprogs
e2fsprogs
bzip2
system-storage-manager

######################
# Packages to Remove #
######################

# Red Hat Enteprise Linux subscription tool
-subscription-manager

# Generic and wireless tools
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
-lvm2

# selinux toolchain of policycoreutils, libsemanage (libselinux is needed tho)
-policycoreutils
-checkpolicy
-selinux-policy*

# Things it would be nice to loose
-fedora-logos
-fedora-release-notes
%end
