%packages --excludedocs
syslinux-nonlinux
dracut-live
centos-logos
memtest86+
rubygem-facter
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
lldpad
elfutils-libs

# Dracut missing deps (https://bugzilla.redhat.com/show_bug.cgi?id=1285810)
tar
gzip

# Facter
ethtool
net-tools
dmidecode
virt-what

# Foreman proxy
foreman-discovery-image-service
sudo
OpenIPMI
openssl

# Interactive discovery
foreman-discovery-image-service-tui
kexec-tools
kbd

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
#
# Some ideas from:
#
# https://github.com/weldr/lorax/blob/rhel7-branch/share/runtime-cleanup.tmpl

# Red Hat Enteprise Linux subscription tool
-subscription-manager

# Generic and wireless tools and firmware
-prelink
-setserial
-ed
-authconfig
-wireless-tools
-iwl7260-firmware
-iwl3160-firmware
-iwl6000g2b-firmware
-iwl6000g2a-firmware
-iwl5000-firmware
-iwl6050-firmware
-iwl2030-firmware
-iwl135-firmware
-iwl2000-firmware
-iwl105-firmware
-iwl1000-firmware
-iwl6000-firmware
-iwl100-firmware
-iwl5150-firmware
-iwl4965-firmware
-iwl3945-firmware
-liquidio-firmware
-netronome-firmware

# Remove the kbd bits
-kbd
-usermode

# file system stuff
-dmraid
-lvm2

# sound and video
-alsa-lib
-alsa-firmware
-alsa-tools-firmware
-ivtv-firmware

# selinux toolchain of policycoreutils, libsemanage (libselinux is needed tho)
-selinux-policy*

# logos and graphics
-plymouth
-fedora-release-notes

# other packages
-postfix
-audit
-rsyslog
-authconfig
-tuned

%end
