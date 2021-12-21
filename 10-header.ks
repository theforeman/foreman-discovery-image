network --bootproto=dhcp
lang en_US.UTF-8
keyboard us
timezone --utc Etc/UTC
selinux --permissive
bootloader --timeout=1 --append="acpi=force"
# root password is "redhat" but account is locked - use fdi.rootpw kernel option
rootpw --iscrypted $1$_redhat_$i3.3Eg7ko/Peu/7Q/1.wJ/
clearpart --all --initlabel
services --disabled=network,sshd --enabled=NetworkManager
# required for lorax
shutdown
# the image currently needs 2.1 GiB but this has been only growing
part / --size 3000 --fstype ext4
