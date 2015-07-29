#!/bin/echo This file is meant to be sourced not to be executed:

# Common functions used in FDI scripts.

# normalize MAC address to use lowercase and : as separator
function normalizeHwAddr() {
  /usr/bin/tr 'A-F-' 'a-f:' <<< "${1}"
}

# parse /proc/cmdline and export parameters into env (KCL_*)
function exportKCL() {
  local -a cmdline
  local param
  IFS=" " read -a cmdline < /proc/cmdline
  for param in "${cmdline[@]}"
  do
    # sanitize variable name to contain only _ and alpha nummeric chars.
    local name="$(/usr/bin/tr -c '[:alnum:]_\n' '_' <<< "${param%%=*}")"
    local value="${param#*=}"
    export "KCL_${name^^}"="${value}"
  done
  if [ -n "${KCL_BOOTIF}" ]
  then
    # strip out leading arp type (01-) of KCL_BOOTIF
    # and provide BOOTMAC in environment
    export BOOTMAC="${KCL_BOOTIF#*-}"
  fi
}
