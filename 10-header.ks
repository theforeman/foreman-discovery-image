# Foreman Discovery base kickstart, based off razor-el-mk
# dc1d03989120e00d50fb8b3f88cb1b99473e5c66

lang en_US.UTF-8
keyboard us
timezone --utc Etc/UTC
auth --useshadow --enablemd5
selinux --permissive
bootloader --timeout=1 --append="acpi=force"
# root password is "redhat" but account is locked - use fdi.rootpw kernel option
rootpw --iscrypted $1$_redhat_$i3.3Eg7ko/Peu/7Q/1.wJ/
part / --size 1900 --fstype ext4 --ondisk sda

services --disabled=network,sshd --enabled=NetworkManager
