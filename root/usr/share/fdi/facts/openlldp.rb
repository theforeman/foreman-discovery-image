# grabbed from:
# https://raw.githubusercontent.com/razorsedge/puppet-openlldp/master/lib/facter/openlldp.rb

#Copyright (C) 2012 Mike Arnold <mike@razorsedge.org>
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.

# Fact:
#   lldp_neighbor_chassisid_<interface>
#   lldp_neighbor_mngaddr_ipv4_<interface>
#   lldp_neighbor_mngaddr_ipv6_<interface>
#   lldp_neighbor_mtu_<interface>
#   lldp_neighbor_portid_<interface>
#   lldp_neighbor_sysname_<interface>
#   lldp_neighbor_pvid_<interface>
#
# Purpose:
#   Return information about the host's LLDP neighbors.
#
# Resolution:
#   On hosts with the lldptool binary, send queries to the lldpad for each of
#   the host's Ethernet interfaces and parse the output.
#
# Caveats:
#   Assumes that the connected Ethernet switch is sending LLDPDUs, Open-LLDP
#   (lldpad) is running, and lldpad is configured to receive LLDPDUs on each
#   Ethernet interface.
#
# Authors:
#   Mike Arnold <mike@razorsedge.org>
#
# Copyright:
#   Copyright (C) 2012 Mike Arnold, unless otherwise noted.
#

require 'facter/util/macaddress'

# http://www.ruby-forum.com/topic/3418285#1040695
module Enumerable
  def grep_v(cond)
    select {|x| not cond === x}
  end
end

#if Facter::Util::Resolution.which('lldptool')
if File.exists?('/usr/sbin/lldptool')
  lldp = {
    # LLDP Name    Numeric value
    'chassisID'    => '1',
    'portID'       => '2',
    'sysName'      => '5',
    'mngAddr_ipv4' => '8',
    'mngAddr_ipv6' => '8',
    'PVID'         => '0x0080c201',
    'MTU'          => '0x00120f04',
  }

  # Remove interfaces that pollute the list (like lo and bond0).
  Facter.value('interfaces').split(/,/).grep_v(/^lo$|^bond[0-9]/).each do |interface|
    # Loop through the list of LLDP TLVs that we want to present as facts.
    lldp.each_pair do |key, value|
      Facter.add("lldp_neighbor_#{key}_#{interface}") do
        setcode do
          result = nil
          output = Facter::Util::Resolution.exec("lldptool get-tlv -n -i #{interface} -V #{value} 2>/dev/null")
          if not output.nil?
            case key
            when 'sysName', 'MTU'
              output.split("\n").each do |line|
                result = $1 if line.match(/^\s+(.*)/)
              end
            when 'chassisID'
              output.split("\n").each do |line|
                ether = $1 if line.match(/MAC:\s+(.*)/)
                result = Facter::Util::Macaddress.standardize(ether)
              end
            when 'portID'
              output.split("\n").each do |line|
                result = $1 if line.match(/(?:Ifname|Local):\s+(.*)/)
              end
            when 'mngAddr_ipv4'
              output.split("\n").each do |line|
                result = $1 if line.match(/IPv4:\s+(.*)/)
              end
            when 'mngAddr_ipv6'
              output.split("\n").each do |line|
                result = $1 if line.match(/IPv6:\s+(.*)/)
              end
            when 'PVID'
              output.split("\n").each do |line|
                result = $1.to_i if line.match(/(?:Info|PVID):\s+(.*)/)
              end
            else
              # case default
              result = nil
            end
          else
            # No output from lldptool
            result = nil
          end
          result
        end
      end
    end
  end
end
