%post

echo " * ensure /etc/os-release is present (needed for RHEL 7.0)"
yum -y install fedora-release centos-release redhat-release-server || \
  touch /etc/os-release

echo " * disabling legacy network services (needed for RHEL 7.0)"
systemctl disable network.service

echo " * enabling NetworkManager system services (needed for RHEL 7.0)"
systemctl enable NetworkManager.service
systemctl enable NetworkManager-dispatcher.service
systemctl enable NetworkManager-wait-online.service

echo " * enabling nm-prepare service"
systemctl enable nm-prepare.service

echo " * enabling required system services"
systemctl enable ipmi.service
systemctl enable foreman-proxy.service
systemctl enable discover-host.service

echo " * setting up foreman proxy"
sed -i "s/.*:http_port:.*/:http_port: 8443/" /etc/foreman-proxy/settings.yml
sed -i "s/.*:daemon:.*/:daemon: true/" /etc/foreman-proxy/settings.yml
sed -i "s/.*:log_level:.*/:log_level: debug/" /etc/foreman-proxy/settings.yml
sed -i 's/.*:enabled:.*/:enabled: true/' /etc/foreman-proxy/settings.d/bmc.yml
sed -i 's/.*:bmc_default_provider:.*/:bmc_default_provider: shell/' /etc/foreman-proxy/settings.d/bmc.yml

echo " * setting up journald and tty1"
rm -f /etc/systemd/system/getty.target.wants/getty@tty1.service
echo "SystemMaxUse=15M" >> /etc/systemd/journald.conf
echo "ForwardToSyslog=no" >> /etc/systemd/journald.conf
echo "ForwardToConsole=yes" >> /etc/systemd/journald.conf
echo "TTYPath=/dev/tty1" >> /etc/systemd/journald.conf

echo " * configuring foreman-proxy"
# required foreman-proxy 1.6.3+ - http://projects.theforeman.org/issues/8006
sed -i 's|.*:log_file:.*|:log_file: STDOUT|' /etc/foreman-proxy/settings.yml
# facts API is disabled by default
echo -e "----\n:enabled: true" > /etc/foreman-proxy/settings.d/facts.yml
/sbin/usermod -a -G tty foreman-proxy

echo " * setting suid bits"
chmod +s /sbin/ethtool
chmod +s /usr/sbin/dmidecode
chmod +s /usr/bin/ipmitool

echo " * setting up FACTERLIB"
sed -i '/\[Service\]/a Environment="FACTERLIB=/usr/share/fdi/facts"' /usr/lib/systemd/system/foreman-proxy.service

# Add foreman-proxy user to sudo and disable interactive tty for reboot
echo " * setting up sudo"
sed -i -e 's/^Defaults.*requiretty/Defaults !requiretty/g' /etc/sudoers
echo "foreman-proxy ALL=NOPASSWD: /sbin/shutdown" >> /etc/sudoers

echo " * dropping some friendly aliases"
echo "alias vim=vi" >> /root/.bashrc
echo "alias rpm=echo DO NOT USE RPM; rpm" >> /root/.bashrc
echo "alias yum=echo DO NOT USE YUM; yum" >> /root/.bashrc

%end
