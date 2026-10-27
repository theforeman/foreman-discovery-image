#!/bin/echo This file is meant to be sourced not to be executed:

# Common functions used in FDI scripts.

# normalize MAC address to use lowercase and : as separator
function normalizeHwAddr() {
  /usr/bin/tr 'A-F-' 'a-f:' <<< "${1}"
}

# FDI_CMDLINE replaces the kernel options for container development. An empty
# override intentionally hides the host's command line too.
function readKCL() {
  if [[ ${FDI_CMDLINE+x} ]]; then
    printf '%s\n' "$FDI_CMDLINE"
  elif [[ -f /run/fdi/cmdline ]]; then
    cat /run/fdi/cmdline
  else
    cat /proc/cmdline
  fi
}

# Parse the effective command line and export parameters into env (KCL_*).
function exportKCL() {
  local -a cmdline
  local param
  local previous
  # Do not inherit values from an earlier parse after changing the override.
  for previous in "${!KCL_@}"; do
    unset "$previous"
  done
  unset BOOTMAC
  IFS=$' \t\n' read -r -a cmdline <<< "$(readKCL | tr '\n' ' ')"
  for param in "${cmdline[@]}"
  do
    # sanitize variable name to contain only _ and alpha nummeric chars.
    local name="$(/usr/bin/tr -c '[:alnum:]_\n' '_' <<< "${param%%=*}")"
    local value="${param#*=}"
    export "KCL_${name^^}"="${value}"
  done
  if [ -n "${KCL_BOOTIF:-}" ]
  then
    # strip out leading arp type (01-) of KCL_BOOTIF
    # and provide BOOTMAC in environment
    export BOOTMAC="${KCL_BOOTIF#*-}"
  fi
}
