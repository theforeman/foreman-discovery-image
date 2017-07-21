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
  if defined? ::Proxy::LoggerFactory
    # helper methods are also used from proxy context (refresh facts -> facter API -> custom facts)
    ::Proxy::LoggerFactory.logger.info msg
  else
    Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.info msg.to_s.gsub('%', '%%') rescue false }
  end
rescue Exception => e
  puts msg
end

def log_err msg
  if defined? ::Proxy::LoggerFactory
    # helper methods are also used from proxy context (refresh facts -> facter API -> custom facts)
    ::Proxy::LoggerFactory.logger.error msg
  else
    Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.err msg.to_s.gsub('%', '%%') rescue false }
  end
rescue Exception => e
  puts msg
end

def log_debug msg
  if defined? ::Proxy::LoggerFactory
    # helper methods are also used from proxy context (refresh facts -> facter API -> custom facts)
    ::Proxy::LoggerFactory.logger.debug msg
  else
    Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS) { |s| s.debug msg.to_s.gsub('%', '%%') rescue false }
  end
rescue Exception => e
  puts msg
end

def log_exception ex
  if ex.is_a? Exception
    backtrace = (ex.to_s + "\n" + ex.backtrace.join("\n")) rescue 'N/A'
    log_err "#{ex.class}: #{ex.message}\n#{backtrace}"
    backtrace
  end
end

def capture_stderr
  previous_stderr, $stderr = $stderr, StringIO.new
  yield
  $stderr.string
ensure
  $stderr = previous_stderr
end

def cmdline_hash
  $cmdline_hash ||= Hash[cmdline.split.map { |x| x.split('=', 2)}]
end

def cmdline option=nil, default=nil
  return File.open("/proc/cmdline", 'r') { |f| f.read } unless option
  cmdline_hash[option] || default
end

def detect_first_nic_with_link
  detection_func = lambda do
    mac = ''
    log_debug "Detecting the first NICs with link"
    Dir.glob('/sys/class/net/*').sort.each do |ifn|
      name = File.basename ifn
      next if name == "lo"
      mac = File.read("#{ifn}/address").chomp rescue ''
      if (File.read("#{ifn}/carrier").chomp == "1" rescue false)
        log_debug "Interface with link found: #{mac} (#{name})"
        return mac
      end
    end
    log_debug "No interfaces with link found, using #{mac}"
    mac
  end
  @detected_mac ||= detection_func.call
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
  default = Resolv::DNS::Config.default_config_hash
  conf = {
    :nameserver => cmdline("fdi.dns_nameserver", default[:nameserver]),
    :search => cmdline("fdi.dns_search", default[:search]),
    :ndots => cmdline("fdi.dns_ndots", default[:ndots]).to_i,
  }
  resolver = Resolv::DNS.new(conf)
  type = Resolv::DNS::Resource::IN::SRV
  result = resolver.getresources("_x-foreman._tcp", type).first
  hostname = result.target.to_s
  if [443, 8443, 9090].include?(result.port)
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
    log_err "Could not determine instance type, add foreman.url or proxy.url kernel command parameter"
    return
  end
  unless uri.is_a? URI
    log_err "Upload#uri must be type of URI"
    return
  end
  if uri.host.nil? or uri.port.nil?
    log_err "Server or proxy URI host or port was not specified, cannot continue"
    return
  end
  log_msg "Registering host at (#{uri})"
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
  # create facts based on user input
  user_input_facts = {"discovery_proxy_uri"=>uri, "discovery_proxy_type"=>type}
  # supress stderr of Facter
  facts = {}
  capture_stderr do
    facts = Facter.to_hash
  end.each_line { |x| log_err x}
  facts.merge!(custom_facts).merge!(user_input_facts)
  req.body = {'facts' => facts }.to_json
  response = http.request(req)
  if ['200','201'].include? response.code
    log_msg "Response from server #{response.code}: #{response.body}"
    body = response.nil? ? 'N/A' : response.body
    write_tui 'success', response.code, body
    return true
  else
    log_err "Response from server #{response.code}: #{response.body}"
    body = response.nil? ? 'N/A' : response.body
    write_tui 'failure', response.code, body
    return false
  end
rescue => e
  log_err "Could not send facts to server: #{e}"
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

def get_mac(interface = 'primary')
  wait = cmdline('fdi.nmwait', 120)
  `nmcli -w #{wait} -t -f 802-3-ethernet.mac-address con show #{interface} 2>/dev/null`.scan(/\w{2}:\w{2}:\w{2}:\w{2}:\w{2}:\w{2}\n/).first.strip rescue 'N/A'
end

def get_ipv4(interface = 'primary')
  wait = cmdline('fdi.nmwait', 120)
  `nmcli -w #{wait} -t -f IP4.ADDRESS con show #{interface} 2>/dev/null`.scan(/\d+\.\d+\.\d+\.\d+\/\d+\n/).first.strip rescue 'N/A'
end

def detect_ipv4_credentials(interface)
  res = {}
  str = `nmcli -t -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS con show #{interface} 2>/dev/null`
  return ["", "", ""] if $? != 0
  str.each_line { |x| kv = x.split(':'); res[kv[0]] = kv[1].chomp }
  [res["IP4.ADDRESS[1]"] || '', res["IP4.GATEWAY"] || '', res["IP4.DNS[1]"] || '']
rescue => e
  log_err e.message
  ["", "", ""]
end
