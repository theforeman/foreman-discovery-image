%post --nochroot
echo " * copying root directory"
cp -r /home/lzap/work/fdi/root $INSTALL_ROOT/var/tmp/
%end

%post
echo " * executing root installation"
pushd /var/tmp/root
bash install chroot
popd
%end
