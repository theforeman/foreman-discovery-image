#!/bin/bash
# Run in a disposable FDI container: these checks replace network profiles.
set -eo pipefail
export FDI_CMDLINE=
source /usr/share/fdi/script-helpers.sh
profiles=/etc/NetworkManager/system-connections
clean_nm

# The helper must work before NetworkManager starts, including a quoted name.
cfg_eth eth0 'Discovery uplink' 'BOOTPROTO=dhcp' 'HWADDR=02:00:00:00:50:10' 'MTU=1400' 'PEERDNS=no' 'DEFROUTE=no'
test "$(stat -c %a "$profiles/eth0.nmconnection")" = 600
grep -qx 'id=Discovery uplink' "$profiles/eth0.nmconnection"
grep -qx 'method=auto' "$profiles/eth0.nmconnection"
grep -qx 'mtu=1400' "$profiles/eth0.nmconnection"
grep -qx 'ignore-auto-dns=true' "$profiles/eth0.nmconnection"
grep -qx 'never-default=true' "$profiles/eth0.nmconnection"

cfg_eth eth0 primary 'BOOTPROTO=none' 'IPADDR=192.0.2.10' 'NETMASK=255.255.255.0' 'GATEWAY=192.0.2.1' 'DNS1=192.0.2.53'
grep -qx 'address1=192.0.2.10/24' "$profiles/eth0.nmconnection"
grep -qx 'gateway=192.0.2.1' "$profiles/eth0.nmconnection"
grep -qx 'dns=192.0.2.53;' "$profiles/eth0.nmconnection"

cfg_eth eth0 primary 'BOOTPROTO=none' 'IPV6INIT=yes' 'IPV6_AUTOCONF=no' 'IPV6ADDR=2001:db8::10/64' 'IPV6_DEFAULTGW=2001:db8::1' 'DNS1=2001:db8::53'
grep -qx 'address1=2001:db8::10/64' "$profiles/eth0.nmconnection"
grep -qx 'gateway=2001:db8::1' "$profiles/eth0.nmconnection"
grep -qx 'dns=2001:db8::53;' "$profiles/eth0.nmconnection"

# These are the existing configure-bond.sh example's calls.
cfg_bond bond0
cfg_slave bond0 eth0
cfg_slave bond0 eth1
grep -qx 'mode=balance-rr' "$profiles/bond0.nmconnection"
grep -qx 'miimon=100' "$profiles/bond0.nmconnection"
grep -qx 'controller=bond0' "$profiles/slave-eth0.nmconnection"
grep -qx 'port-type=bond' "$profiles/slave-eth1.nmconnection"
if grep -q '^\[ipv[46]\]' "$profiles/slave-eth0.nmconnection"; then exit 1; fi

cfg_bond bond0 'miimon=100 mode=active-backup primary=eth0' static primary 'IPADDR=192.0.2.20' 'PREFIX=24' 'DNS1=192.0.2.53'
grep -qx 'mode=active-backup' "$profiles/bond0.nmconnection"
grep -qx 'primary=eth0' "$profiles/bond0.nmconnection"
grep -qx 'address1=192.0.2.20/24' "$profiles/bond0.nmconnection"

# Invalid input must not overwrite a working profile or execute shell text.
before=$(sha256sum "$profiles/eth0.nmconnection")
if cfg_eth eth0 primary 'UNSUPPORTED_SETTING=yes'; then exit 1; fi
test "$before" = "$(sha256sum "$profiles/eth0.nmconnection")"
cfg_eth eth2 '$(touch /tmp/fdi-unexpected-command)' 'BOOTPROTO=dhcp'
test ! -e /tmp/fdi-unexpected-command

clean_nm
test -z "$(ls -A "$profiles")"
echo 'Offline Ethernet, static IPv4/IPv6 and bond helper profiles passed'
