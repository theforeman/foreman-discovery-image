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
require 'syslog'
require 'facter'
require 'yaml'
require 'json'

def log_msg msg
  Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.info msg.to_s }
end

def log_err msg
  Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.err msg.to_s }
end

def log_debug msg
  Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.debug msg.to_s }
end

def cmdline option=nil, default=nil
  @cmdline ||= File.open("/proc/cmdline", 'r') { |f| f.read }
  if option
    result = @cmdline.split.map { |x| $1 if x.match(/^#{option}=(.*)/)}.compact
    result.size == 1 ? result.first : default
  else
    @cmdline
  end
end

def normalize_mac mac
  mac.split('-')[1..6].join(':') rescue nil
end

def discover_server
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

def write_tui result = 'success', code, body
  filename = "/tmp/discovery-http-#{result}"
  log_debug "Wrote result #{code} to #{filename}"
  File.open(filename, 'w') do |file|
    file.write("#{code}: #{body}")
  end
end

def upload(uri = discover_server, type = proxy_type, custom_facts = {})
  unless uri
    log_err "Could not determine Foreman instance, add foreman.url or proxy.url kernel command parameter"
    return
  end
  unless uri.is_a? URI
    log_err "Upload#uri must be type of URI"
    return
  end
  if uri.host.nil? or uri.port.nil?
    log_err "Foreman URI host or port was not specified, cannot continue"
    return
  end
  log_msg "Registering host with Foreman (#{uri})"
  http = Net::HTTP.new(uri.host, uri.port)
  if uri.scheme == 'https' then
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  end
  facts_url = if type == 'proxy'
                "#{uri.path}/discovery/create"
              else
                "#{uri.path}/api/v2/discovered_hosts/facts"
              end
  req = Net::HTTP::Post.new(facts_url, {'Content-Type' => 'application/json'})
  facts = Facter.to_hash
  facts.merge!(custom_facts)
  req.body = {'facts' => facts }.to_json
  response = http.request(req)
  if ['200','201'].include? response.code
    log_msg "Response from Foreman #{response.code}: #{response.body}"
    body = response.nil? ? 'N/A' : response.body
    write_tui 'success', response.code, body
    return true
  else
    log_err "Response from Foreman #{response.code}: #{response.body}"
    body = response.nil? ? 'N/A' : response.body
    write_tui 'failure', response.code, body
    return false
  end
rescue => e
  log_err "Could not send facts to Foreman: #{e}"
  log_debug e.backtrace.join("\n")
  body = response.nil? ? 'N/A' : response.body
  write_tui 'failure', 1001, "#{e}, body: #{body}"
  return false
end

# Quick function to append to ENV vars correctly
def env_append(env,string)
  if ENV[env].nil? or ENV[env].empty?
    "#{env}=#{string}\n"
  else
    "#{env}=#{ENV[env]}:#{string}\n"
  end
end

def detect_ipv4_credentials(interface)
  res = {}
  str = `nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS con show #{interface}`
  return ["", "", ""] if $? != 0
  str.each_line { |x| kv = x.split(':'); res[kv[0]] = kv[1].chomp }
  [res["IP4.ADDRESS[1]"] || '', res["IP4.GATEWAY"] || '', res["IP4.DNS[1]"] || '']
rescue => e
  log_err e.message
  ["", "", ""]
end
