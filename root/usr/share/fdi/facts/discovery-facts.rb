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

require 'facter/util/ip'
require '/usr/lib64/ruby/vendor_ruby/discovery.rb'

def cmdline option=nil, default=nil
  line = File.open("/proc/cmdline", 'r') { |f| f.read }
  if option
    result = line.split.map { |x| $1 if x.match(/^#{option}=(.*)/)}.compact
    result.size == 1 ? result.first : default
  else
    line
  end
end

def discovery_bootif
  # PXELinux dash-separated hexadecimal *without* the leading hardware type
  cmdline('BOOTIF', cmdline('fdi.pxmac', detect_first_nic_with_link)).gsub(/^[a-fA-F0-9]+-/, '').gsub('-', ':') rescue '00:00:00:00:00:00'
end

Facter.add("discovery_version") do
  setcode do
    File.open('/usr/share/fdi/VERSION') {|f| f.readline.chomp}
  end
end

Facter.add("discovery_release") do
  setcode do
    File.open('/usr/share/fdi/RELEASE') {|f| f.readline.chomp}
  end
end

Facter.add("discovery_bootif", :timeout => 10) do
  setcode do
    discovery_bootif
  end
end

Facter.add("discovery_bootip", :timeout => 10) do
  setcode do
    result = Facter.fact("ipaddress").value
    required = discovery_bootif
    Facter::Util::IP.get_interfaces.each do |iface|
      mac = Facter::Util::IP.get_interface_value(iface, "macaddress")
      result = Facter::Util::IP.get_interface_value(iface, "ipaddress") if mac == required
    end
    result
  end
end

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
        attributes[:auto_negotiation] = ($1 == 'on').to_s
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
      Facter.add("#{fact}_#{Facter::Util::IP.alphafy(interface)}", :timeout => 10) do
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

def add_ipmi_facts fact, value, channel = nil
  if channel
    fact = "ipmi_#{channel}_#{fact}"
  else
    fact = "ipmi_#{fact}"
  end
  Facter.add(fact) do
    confine :kernel => "Linux"
    setcode do
      value
    end
  end
end

if has_ipmi
  Facter.add("ipmi_enabled") do
    confine :kernel => "Linux"
    setcode do
      true
    end
  end
  default_found = false
  (0..15).each do |n|
    output = Facter::Util::Resolution.exec("ipmitool lan print #{n} 2>/dev/null")
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

    unless default_found
      Facter.debug("Running ipmitool on port #{n} didn't give any information") if attributes.keys.empty?
      attributes.each do |fact, value|
        add_ipmi_facts fact, value
        default_found = true
      end
    end
    attributes.each do |fact, value|
      add_ipmi_facts fact, value, n
    end
  end
end
