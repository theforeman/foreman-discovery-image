# Try to minimize the image a bit
%post

# Ensure we don't have the same random seed on every image, which
# could be bad for security at a later point...
echo " * purge existing random seed to avoid identical seeds everywhere"
rm -f /var/lib/random-seed

echo " * disable sshd and purge existing SSH host keys"
rm -f /etc/ssh/ssh_host_*key{,.pub}
systemctl disable sshd.service

# This seems to cause 'reboot' resulting in a shutdown on certain platforms
# See https://tickets.puppetlabs.com/browse/RAZOR-100
echo " * remove intel mei modules"
rm -rf /lib/modules/*/kernel/drivers/misc/mei

# See https://bugzilla.redhat.com/show_bug.cgi?id=1335830
echo " * remove some video drivers to prevent kexec isues"
rm -rf /lib/modules/*/kernel/drivers/gpu/drm \
  /lib/modules/*/kernel/drivers/video/fbdev \
  /lib/firmware/{amdgpu,radeon}

echo " * remove unused drivers (sound, media, nls)"
rm -rf /lib/modules/*/kernel/{sound,drivers/media,fs/nls}

echo " * remove unused firmware (sound, wifi)"
rm -rf /usr/lib/firmware/*wifi* \
  /usr/lib/firmware/v4l* \
  /usr/lib/firmware/dvb* \
  /usr/lib/firmware/{yamaha,korg,liquidio,emu,dsp56k,emi26}

echo " * dropping big and compressing small cracklib dict"
mv -f /usr/share/cracklib/cracklib_small.hwm /usr/share/cracklib/pw_dict.hwm
mv -f /usr/share/cracklib/cracklib_small.pwd /usr/share/cracklib/pw_dict.pwd
mv -f /usr/share/cracklib/cracklib_small.pwi /usr/share/cracklib/pw_dict.pwi
gzip -9 /usr/share/cracklib/pw_dict.pwd

# remove things only needed during the build process
echo " * purging packages needed only during build"
rpm -e syslinux mtools acl

# 100MB of locale archive is kind unnecessary; we only do en_US.utf8
# this will clear out everything we don't need; 100MB => 2.1MB.
echo " * minimizing locale-archive binary / memory size"
localedef --list-archive | grep -Eiv '(en_US|fdi)' | xargs localedef -v --delete-from-archive
mv /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
/usr/sbin/build-locale-archive

echo " * purging all other locale data"
ls -d /usr/share/locale/* | grep -v fdi | xargs rm -rf

echo " * purging images"
rm -rf /usr/share/backgrounds/* /usr/share/kde4/* /usr/share/anaconda/pixmaps/rnotes/*

echo " * purging rubygems cache"
rm -rf /usr/share/gems/cache/*

echo " * truncating various logfiles"
for log in yum.log dracut.log lastlog yum.log; do
    truncate -c -s 0 /var/log/${log}
done

echo " * removing /boot, since that lives on the ISO side"
rm -rf /boot*

echo " * removing trusted CA certificates"
truncate -s0 /usr/share/pki/ca-trust-source/ca-bundle.trust.crt
update-ca-trust

echo " * setting up hostname"
echo fdi > /etc/hostname

echo " * locking root account"
passwd -l root

echo " * store list of packages sorted by size"
rpm -qa --queryformat '%{SIZE} %{NAME}%{VERSION}%{RELEASE}\n' | sort -n -r > /usr/PACKAGES-LIST

echo " * cleaning up yum cache and removing rpm database"
yum clean all
rm -rf /var/lib/{yum,rpm}/*
# fix the vim syntax markup */

# no more python loading after this step
echo " * removing python precompiled *.pyc files"
find /usr/lib64/python*/ /usr/lib/python*/ -name *py[co] -print0 | xargs -0 rm -f
%end

%post --nochroot
echo " * disquieting the boot process"
sed -i -e's/ rhgb//g' -e's/ quiet//g' $LIVE_ROOT/isolinux/isolinux.cfg
%end
