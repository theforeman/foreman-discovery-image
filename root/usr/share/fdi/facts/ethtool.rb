#!/usr/bin/env ruby
#
# Quickfix for regression introduced in FDI 3.7.0
# See: https://community.theforeman.org/t/foreman-discovery-image-3-7/21642
#
# To test:
# $ FACTERLIB=/usr/share/fdi/facts ruby /opt/theforeman/tfm/root/usr/bin/facter

require 'facter'

Facter.add(:ethtool, :timeout => 10) do
  confine kernel: "Linux"

  confine :networking do |value|
    value && value['interfaces']
  end

  confine do
    Facter::Core::Execution.which('ethtool') != nil
  end

  setcode do
    interface_info = {}
    Facter.value(:networking)['interfaces'].keys.each do |interface|
      Facter.debug("Running ethtool on interface #{interface}")
      output = Facter::Core::Execution.exec("ethtool #{interface} 2>/dev/null")
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
        else
          interface_info[interface] = attributes
        end
      end
    end
    interface_info
  end
end
