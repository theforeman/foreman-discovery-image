# Try to minimize the image a bit
%post

# But first ensure that /etc/os-release is installed
echo " * ensure /etc/os-release is present"
yum -y install fedora-release centos-release redhat-release-server

# Ensure we don't have the same random seed on every image, which
# could be bad for security at a later point...
echo " * purge existing random seed to avoid identical seeds everywhere"
rm -f /var/lib/random-seed

# I can't tell if this should force a new SSH key, or force a fixed one,
# but for now we can ensure that we generate new keys when SSHD is finally
# fined up on the nodes...
#
# We also disable SSHd automatic startup in the final image.
echo " * disable sshd and purge existing SSH host keys"
rm -f /etc/ssh/ssh_host_*key{,.pub}
systemctl disable sshd.service

# This seems to cause 'reboot' resulting in a shutdown on certain platforms
# See https://tickets.puppetlabs.com/browse/RAZOR-100
echo " * disable the mei_me module"
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/mei.conf <<EOMEI
blacklist mei_me
install mei_me /bin/true
blacklist mei
install mei /bin/true
EOMEI

echo " * compressing cracklib dictionary"
gzip -9 /usr/share/cracklib/pw_dict.pwd

# remove things only needed during the build process
echo " * purging packages needed only during build"
rpm -e syslinux mtools acl ebtables firewalld \
  libselinux-python python-decorator dracut hardlink kpartx \
  python-slip python-slip-dbus

# 100MB of locale archive is kind unnecessary; we only do en_US.utf8
# this will clear out everything we don't need; 100MB => 2.1MB.
echo " * minimizing locale-archive binary / memory size"
localedef --list-archive | grep -iv 'en_US' | xargs localedef -v --delete-from-archive
mv /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
/usr/sbin/build-locale-archive

echo " * purging all other locale data"
rm -rf /usr/share/locale*

echo " * cleaning up yum cache, etc"
yum clean all

echo " * truncating various logfiles"
for log in yum.log dracut.log lastlog yum.log; do
    truncate -c -s 0 /var/log/${log}
done

echo " * removing /boot, since that lives on the ISO side"
rm -rf /boot*

echo " * removing python precompiled *.pyc files"
find /usr/lib64/python*/ -name *pyc -print0 | xargs -0 rm -f

echo " * removing trusted CA certificates"
truncate -s0 /usr/share/pki/ca-trust-source/ca-bundle.trust.crt
update-ca-trust

echo " * setting up hostname"
echo fdi > /etc/hostname

echo " * locking root account"
passwd -l root
%end

%post --nochroot
echo " * disquieting the microkernel boot process"
sed -i -e's/ rhgb//g' -e's/ quiet//g' $LIVE_ROOT/isolinux/isolinux.cfg
%end
