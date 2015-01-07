# Library of functions for use with Foreman Discovery
#
# vim: ts=2:sw=2:et
#
# Copyright (C) 2012-2014 Red Hat, Inc.
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

require 'fileutils'
require 'net/http'
require 'net/https'
require 'uri'
require 'socket'
require 'resolv'

def log_msg msg
  puts msg
end

def log_err msg
  $stderr.puts msg
end

def cmdline option=nil, default=nil
  line = File.open("/proc/cmdline", 'r') { |f| f.read }
  if option
    result = line.split.map { |x| $1 if x.match(/^#{option}=(.*)/)}.compact
    result.size == 1 ? result.first : default
  else
    line
  end
end

def discover_server
  log_msg "Parsing kernel line: #{cmdline}"
  discover_by_url || discover_by_dns_srv
end

def discover_by_url
  url = cmdline('proxy.url') || cmdline('foreman.url')
  log_msg "Discovered by URL: #{url}" if url
  URI.parse(url)
rescue
  return nil
end

# SRV discovery will work only if DHCP returns valid search domain
def discover_by_dns_srv
  resolver = Resolv::DNS.new
  type = Resolv::DNS::Resource::IN::SRV
  result = resolver.getresources("_x-foreman._tcp", type).first
  hostname = result.target.to_s
  if result.port == 443
    scheme = 'https'
  else
    scheme = 'http'
  end
  uri = "#{scheme}://#{hostname}:#{result.port}"
  log_msg "Discovered by SRV: #{uri}"
  URI.parse(uri)
rescue
  return nil
end

def proxy_type
  type = cmdline('proxy.type', 'foreman')
  log_err('*** proxy.type should be either "foreman" or "proxy" ***') unless ['foreman', 'proxy'].include? type
  type
end

# Quick function to append to ENV vars correctly
def env_append(env,string)
  if ENV[env].nil? or ENV[env].empty?
    "#{env}=#{string}\n"
  else
    "#{env}=#{ENV[env]}:#{string}\n"
  end
end
