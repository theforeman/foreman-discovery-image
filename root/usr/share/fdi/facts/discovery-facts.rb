#!/usr/bin/env ruby
# vim: ts=2:sw=2:et
#
# Copyright (C) 2013 Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.  A copy of the GNU General Public License is
# also available at http://www.gnu.org/copyleft/gpl.html.

def cmdline option=nil, default=nil
  line = File.open("/proc/cmdline", 'r') { |f| f.read }
  if option
    result = line.split.map { |x| $1 if x.match(/^#{option}=(.*)/)}.compact
    result.size == 1 ? result.first : default
  else
    line
  end
end

Facter.add("discovery_bootif") do
  setcode do
    # PXELinux dash-separated hexadecimal *without* the leading hardware type
    cmdline('BOOTIF', Facter.fact("macaddress").value).gsub(/^[a-fA-F0-9]+-/, '').gsub('-', ':') rescue '00:00:00:00:00:00'
  end
end

# Additional interface facts
require 'facter/util/ip'

Facter::Util::IP.get_interfaces.each do |interface|
  Facter.debug("Running ethtool on interface #{interface}")
  output = (Facter::Util::Resolution.exec("ethtool #{interface} 2>/dev/null"))
  if output.nil?
    Facter.debug("Execution of ethtool on interface #{interface} failed")
  else
    attributes = {}
    output.each_line do |line|
      next if line.nil? or line == ""
      case line.strip
      when /Speed: (.*)Mb/
        attributes[:speed] = $1
      when /Duplex: (.*)/
        attributes[:duplex] = $1.downcase
      when /Port: (.*)/
        attributes[:port] = $1
      when /Auto-negotiation: (.*)/
        attributes[:auto_negotitation] = ($1 == 'on').to_s
      when /^Wake-on: (.*)/
        attributes[:wol] = $1.include?('g')
      when /Link detected: (.*)/
        attributes[:link] = ($1 == 'yes').to_s
      end
    end

    if attributes.keys.empty?
      Facter.debug("Running ethtool on #{interface} didn't give any information")
    end
    attributes.each do |fact, value|
      Facter.add("#{fact}_#{Facter::Util::IP.alphafy(interface)}") do
        confine :kernel => "Linux"
        setcode do
          value
        end
      end
    end
  end
end

# IPMI Facts
%x{dmidecode -t 38 2>/dev/null|grep -q "IPMI Device"}
has_ipmi = $?.exitstatus == 0

if has_ipmi
  output = Facter::Util::Resolution.exec("ipmitool lan print 1 2>/dev/null")
  attributes = {}
  output.each_line do |line|
    case line.strip
    when /^IP Address Source\s+: (.*)/
      attributes[:ipaddress_source] = $1
    when /^IP Address\s+: (.*)/
      attributes[:ipaddress] = $1
    when /^Subnet Mask\s+: (.*)/
      attributes[:subnet_mask] = $1
    when /^MAC Address\s+: (.*)/
      attributes[:macaddress] = $1
    when /^Default Gateway IP\s+: (.*)/
      attributes[:gateway] = $1
    end
  end if output

  if attributes.keys.empty?
    Facter.debug("Running ipmitool didn't give any information")
  end
  attributes[:enabled] = true
  attributes.each do |fact, value|
    Facter.add("ipmi_#{fact}") do
      confine :kernel => "Linux"
      setcode do
        value
      end
    end
  end

end
