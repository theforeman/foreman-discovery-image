#!/bin/bash
# Runs inside the container build; invoked by the Containerfile.
set -euo pipefail
case "${FDI_SSH}" in 0|1) ;; *) echo 'FDI_SSH must be 0 or 1' >&2; exit 1 ;; esac
case "${FDI_SELINUX}" in permissive|enforcing) ;; *) echo 'FDI_SELINUX must be permissive or enforcing' >&2; exit 1 ;; esac

printf '%s\n' "${FDI_VERSION}" > /usr/share/fdi/VERSION
printf '%s\n' "${FDI_RELEASE}" > /usr/share/fdi/RELEASE
echo fdi > /etc/hostname
echo LANG=en_US.UTF-8 > /etc/locale.conf
echo KEYMAP=us > /etc/vconsole.conf
ln -snf /usr/share/zoneinfo/Etc/UTC /etc/localtime
sed -i "s/^SELINUX=.*/SELINUX=${FDI_SELINUX}/" /etc/selinux/config

mkdir -p /etc/NetworkManager/system-connections /etc/foreman-proxy/settings.d
cat > /etc/NetworkManager/NetworkManager.conf <<'NM'
[main]
monitor-connection-files=no
no-auto-default=*
[logging]
level=DEBUG
NM
cat > /etc/modules-load.d/tftp-firewall.conf <<'MODULES'
nf_conntrack_tftp
nf_conntrack_netbios_ns
MODULES
cat > /etc/udev/rules.d/81-nm-prepare.rules <<'UDEV'
ACTION=="add", SUBSYSTEM=="net", NAME!="lo", RUN+="/usr/bin/systemd-cat -t nm-prepare /usr/bin/nm-prepare %k"
UDEV
cat > /etc/udev/rules.d/82-enable-lldp.rules <<'UDEV'
ACTION=="add", SUBSYSTEM=="net", NAME!="lo", TAG+="systemd", ENV{SYSTEMD_WANTS}+="enable-lldp@%k.service"
UDEV
cat > /etc/udev/rules.d/83-enable-promiscuous-mode.rules <<'UDEV'
ACTION=="add", SUBSYSTEM=="net", NAME!="lo", TAG+="systemd", ENV{SYSTEMD_WANTS}+="enable-promiscuous-mode@%k.service"
UDEV

cat > /etc/foreman-proxy/settings.yml <<'PROXY'
---
:settings_directory: /etc/foreman-proxy/settings.d
:ssl_certificate: /etc/foreman-proxy/cert.pem
:ssl_ca_file: /etc/foreman-proxy/cert.pem
:ssl_private_key: /etc/foreman-proxy/key.pem
:daemon: true
:http_port: 8448
:https_port: 8443
:log_file: SYSLOG
:log_level: DEBUG
:log_buffer: 1000
:log_buffer_errors: 500
PROXY
for plugin in discovery_image facts logs; do
    printf '%s\n' '---' ':enabled: true' > "/etc/foreman-proxy/settings.d/${plugin}.yml"
done
cat > /etc/foreman-proxy/settings.d/bmc.yml <<'BMC'
---
:enabled: true
:bmc_default_provider: shell
BMC
usermod -a -G tty foreman-proxy
chmod u+s /usr/sbin/ethtool /usr/sbin/dmidecode /usr/bin/ipmitool
cat > /etc/sudoers.d/fdi <<'SUDOERS'
Defaults:foreman-proxy !requiretty
foreman-proxy ALL=(root) NOPASSWD: /usr/sbin/reboot, /usr/sbin/shutdown, /usr/sbin/kexec
SUDOERS
chmod 0440 /etc/sudoers.d/fdi
visudo -cf /etc/sudoers

mkdir -p /etc/systemd/system.conf.d /etc/systemd/journald.conf.d
printf '[Manager]\nDumpCore=no\n' > /etc/systemd/system.conf.d/fdi.conf
cat > /etc/systemd/journald.conf.d/fdi.conf <<'JOURNAL'
[Journal]
Storage=volatile
RuntimeMaxUse=25M
ForwardToSyslog=no
ForwardToConsole=no
JOURNAL
systemctl set-default multi-user.target
systemctl enable NetworkManager.service NetworkManager-dispatcher.service \
    NetworkManager-wait-online.service nm-prepare.service foreman-proxy.service \
    discovery-fetch-extensions.path discovery-menu.service \
    discovery-start-builtin-extensions.service \
    discovery-script-pxe.service discovery-script-pxeless.service \
    journalctl.service lldpad.socket
# Registration is started by the TUI. PXE extension startup is triggered by
# the existing DHCP dispatcher/path unit; the extra unit handles PXE-less boots.
systemctl disable sshd.service ipmi.service
systemctl mask getty@tty1.service getty@tty2.service systemd-journal-flush.service \
    kdump.service firewalld.service bootc-generic-growpart.service \
    bootc-publish-rhsm-facts.service bootc-fetch-apply-updates.timer \
    bootloader-update.service

# Keep the extension API at /opt/extension, but seed its writable contents at
# boot using tmpfiles. This also supports extensions supplied in root/opt/extension.
mkdir -p /opt/extension/{bin,lib/ruby,facts,autostart.d}
mv /opt/extension /usr/share/fdi/extension
ln -s /var/opt/extension /opt/extension

passwd -l root
if [[ -n "${FDI_ROOT_PASSWORD_HASH}" ]]; then
    [[ "${FDI_ROOT_PASSWORD_HASH}" == \$* ]] || { echo 'Supply a crypt password hash, not a plaintext password' >&2; exit 1; }
    printf 'root:%s\n' "${FDI_ROOT_PASSWORD_HASH}" | chpasswd -e
fi
if [[ "${FDI_SSH}" == 1 ]]; then
    # Match rc.local's fdi.ssh=1 behavior, including root/password authentication.
    cat > /etc/ssh/sshd_config.d/00-fdi.conf <<'SSH'
PubkeyAuthentication yes
PasswordAuthentication yes
PermitRootLogin yes
SSH
    systemctl enable sshd.service
fi
rm -f /etc/ssh/ssh_host_*key /etc/ssh/ssh_host_*key.pub
rm -f /var/lib/random-seed /var/lib/systemd/random-seed
truncate -s 0 /etc/machine-id

# Keep the distribution's kernel, modules, firmware and package metadata intact.
# The old LiveCD's aggressive file pruning is not applied here.
rm -rf /usr/share/gems/cache/*

if [[ -n "${EXTRA_DRIVERS}" ]]; then
    # Validate before interpolating into a dracut shell configuration file.
    [[ "${EXTRA_DRIVERS}" =~ ^[a-zA-Z0-9_\ -]+$ ]] || { echo 'Invalid EXTRA_DRIVERS' >&2; exit 1; }
    printf 'add_drivers+=" %s "\n' "${EXTRA_DRIVERS}" > /etc/dracut.conf.d/99-fdi-extra.conf
fi
# Exactly one target kernel must be present; never use the build host's uname.
mapfile -t kernels < <(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n')
[[ ${#kernels[@]} -eq 1 ]] || { echo 'Expected exactly one kernel in /usr/lib/modules' >&2; exit 1; }
kver="${kernels[0]}"
depmod -a "${kver}"
DRACUT_NO_XATTR=1 dracut --force "/usr/lib/modules/${kver}/initramfs.img" "${kver}"
rpm -qa --queryformat '%{SIZE} %{NAME} %{VERSION}%{RELEASE}\n' | sort -nr > /usr/PACKAGES-LIST
dnf clean all
# RPM scriptlets create runtime state while building; recreate it with the
# packages' tmpfiles rules on boot instead of embedding caches or logfiles.
rm -rf /var/cache/dnf /var/lib/dnf /var/cache/ldconfig /var/lib/rhsm/*
find /var/log -type f -delete
rm -rf /run/foreman-proxy /run/rhsm
# EL10's kdump dracut hook leaves a build-time lock behind.
rm -f /tmp/kdump.lock /tmp/fdi-configure.sh
if [[ -d /var/roothome/buildinfo ]]; then
    mv /var/roothome/buildinfo /usr/share/fdi/base-buildinfo
fi
# composefs is deliberately disabled for the squashfs PXE root.
bootc container lint --skip baseimage-composefs --fatal-warnings
