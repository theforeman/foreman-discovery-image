#!/bin/bash
source /etc/default/discovery
source /usr/share/fdi/commonfunc.sh
exportKCL

# helper functions
clean_nm() {
  rm -f /etc/NetworkManager/system-connections/*
}

no_tui() {
  touch /tmp/disable-menu
}

reload_nm() {
  # in PXE-less mode NM is not yet started - this will fail
  nmcli connection reload 2>/dev/null || true
}

discover_now() {
  nohup /usr/bin/discovery-register &> /tmp/discovery-script-register.log &
}

enable_discovery() {
  systemctl enable discovery-register
}

hwaddr() {
  HWADDR=$(cat /sys/class/net/$1/address)
}

cfg_eth() {
  DEVICE=${1:-eth0}
  NAME=${2:-$DEVICE}
  cat >/etc/sysconfig/network-scripts/ifcfg-$DEVICE <<EOF
TYPE=Ethernet
NAME=$NAME
DEVICE=$DEVICE
ONBOOT=yes
$3
$4
$5
$6
$7
$8
$9
EOF
}

cfg_bond() {
  DEVICE=${1:-bond0}
  OPTS=${2:-miimon=100 mode=balance-rr}
  BOOTPROTO=${3:-dhcp}
  NAME=${4:-$DEVICE}
  cat >/etc/sysconfig/network-scripts/ifcfg-$DEVICE <<EOF
TYPE=Bond
ONBOOT=yes
DEVICE=$DEVICE
BONDING_MASTER=yes
BONDING_OPTS="$OPTS"
BOOTPROTO=$BOOTPROTO
DEFROUTE=yes
IPV6INIT=no
NAME=$NAME
$5
$6
$7
$8
$9
EOF
}

cfg_slave() {
  MASTER=${1:-bond0}
  DEV=${2:-eth0}
  cat >/etc/sysconfig/network-scripts/ifcfg-slave-$DEV <<EOF
TYPE=Ethernet
NAME=slave-$DEV
DEVICE=$DEV
ONBOOT=yes
MASTER=$MASTER
SLAVE=yes
$3
$4
$5
$6
$7
$8
$9
EOF
}

fact() {
  echo "$2" > "/tmp/facts/$1"
}

set +x
