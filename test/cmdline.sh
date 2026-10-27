#!/bin/bash
# Run inside a disposable FDI container; this rewrites its primary connection.
set -euo pipefail

unset FDI_CMDLINE
rm -f /run/fdi/cmdline
test "$(discovery-cmdline)" = "$(cat /proc/cmdline)"
ruby -r discovery -e 'abort "kernel fallback" unless cmdline == File.read("/proc/cmdline")'

# An explicitly empty override must not accidentally expose the host's options.
export FDI_CMDLINE=
test -z "$(discovery-cmdline)"
ruby -r discovery -e 'abort "empty override" unless cmdline.empty? && cmdline("BOOTIF").nil?'
discovery-cmdline --missing BOOTIF
if discovery-cmdline --has BOOTIF; then exit 1; fi

# Services and dispatchers can lose the original environment. The entrypoint
# snapshot must still reach shell and unprivileged Ruby readers.
FDI_CMDLINE='BOOTIF=01-02-00-00-00-50-10 custom=snapshot' discovery-container-entrypoint /bin/true
unset FDI_CMDLINE
discovery-cmdline --has BOOTIF
ruby -r discovery -e 'abort "service snapshot" unless cmdline("custom") == "snapshot"'
FDI_CMDLINE= ruby -r discovery -e 'abort "environment precedence" unless cmdline.empty?'
FDI_CMDLINE= discovery-container-entrypoint /bin/true
test -z "$(discovery-cmdline)"
ruby -r discovery -e 'abort "empty service snapshot" unless cmdline.empty?'
rm /run/fdi/cmdline

export FDI_CMDLINE=$'BOOTIF=01-02-00-00-00-50-10\nfdi.pxip=10.89.50.10/24 fdi.pxgw=10.89.50.1 fdi.pxdns=10.89.50.1\nfdi.nopromis custom=a=b'
source /usr/share/fdi/commonfunc.sh
exportKCL
test "$BOOTMAC" = 02-00-00-00-50-10
test "$KCL_FDI_PXIP" = 10.89.50.10/24
test "$KCL_CUSTOM" = a=b
discovery-cmdline --has BOOTIF
discovery-cmdline --has fdi.nopromis
discovery-cmdline --missing fdi.nopromis.extra
if discovery-cmdline --missing BOOTIF; then exit 1; fi
if discovery-cmdline --has BOOT; then exit 1; fi
ruby -r discovery -e '
  abort "override" unless cmdline == ENV.fetch("FDI_CMDLINE")
  abort "multiline" unless cmdline("fdi.pxip") == "10.89.50.10/24"
  abort "equals in value" unless cmdline("custom") == "a=b"
  abort "default" unless cmdline("missing", "fallback") == "fallback"
'

nm-configure primary-boot
grep -qx 'address1=10.89.50.10/24' /etc/NetworkManager/system-connections/primary
grep -qx 'gateway=10.89.50.1' /etc/NetworkManager/system-connections/primary
grep -qx 'dns=10.89.50.1;' /etc/NetworkManager/system-connections/primary
test "$(stat -c %a /etc/NetworkManager/system-connections/primary)" = 600

# Choosing DHCP explicitly in the TUI must still override boot-time static IP.
nm-configure primary
grep -qx 'method=auto' /etc/NetworkManager/system-connections/primary
if grep -q '^address1=' /etc/NetworkManager/system-connections/primary; then exit 1; fi

export FDI_CMDLINE='BOOTIF=01-02-00-00-00-50-10 fdi.pxip=2001:db8::10/64 fdi.pxgw=2001:db8::1 fdi.pxdns=2001:db8::53'
nm-configure primary-boot
grep -qx 'address1=2001:db8::10/64' /etc/NetworkManager/system-connections/primary
grep -qx 'method=disabled' /etc/NetworkManager/system-connections/primary

export FDI_CMDLINE='BOOTIF=01-02-00-00-00-50-10'
nm-configure primary-boot
grep -qx 'method=auto' /etc/NetworkManager/system-connections/primary
if grep -q '^address1=' /etc/NetworkManager/system-connections/primary; then exit 1; fi

echo 'Command-line readers, conditions and static/DHCP profiles passed'
