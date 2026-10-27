# frozen_string_literal: true

require 'ipaddr'
require 'open3'
require 'shellwords'
require 'tempfile'

# Translate the IP settings shared by Ethernet and bond profiles.
module DiscoveryIPSettings
  def ipv4
    addresses = []
    ['', *0..255].each do |suffix|
      address = take("IPADDR#{suffix}")
      prefix = take("PREFIX#{suffix}")
      netmask = take("NETMASK#{suffix}")
      next unless address

      prefix ||= IPAddr.new("0.0.0.0/#{netmask}").prefix if netmask
      # ifcfg defaults to the traditional classful mask when no mask is given.
      prefix ||= if address.split('.').first.to_i < 128
                   8
                 else
                   (address.split('.').first.to_i < 192 ? 16 : 24)
                 end
      addresses << (address.include?('/') ? address : "#{address}/#{prefix}")
    end
    protocol = take('BOOTPROTO', 'none').downcase
    method = { 'none' => 'manual', 'static' => 'manual', 'dhcp' => 'auto', 'bootp' => 'auto',
               'autoip' => 'link-local', 'shared' => 'shared' }.fetch(protocol) do
      raise ArgumentError, "Unsupported BOOTPROTO=#{protocol}"
    end
    method = 'disabled' if method == 'manual' && addresses.empty?
    @properties['ipv4.method'] = method
    @properties['ipv4.addresses'] = addresses.join(',') unless addresses.empty?
    copy('GATEWAY', 'ipv4.gateway')
    copy('IPV4_ROUTE_METRIC', 'ipv4.route-metric')
    copy('DHCP_HOSTNAME', 'ipv4.dhcp-hostname')
    copy('DHCP_FQDN', 'ipv4.dhcp-fqdn')
    copy('DHCP_CLIENT_ID', 'ipv4.dhcp-client-id')
    copy('DHCP_TIMEOUT', 'ipv4.dhcp-timeout')
    copy('IPV4_DHCP_TIMEOUT', 'ipv4.dhcp-timeout')
    copy('IPV4_ROUTE_TABLE', 'ipv4.route-table')
    copy('IPV4_DNS_PRIORITY', 'ipv4.dns-priority')
    boolean('DHCP_SEND_HOSTNAME', 'ipv4.dhcp-send-hostname')
    boolean('DEFROUTE', 'ipv4.never-default', invert: true)
    boolean('PEERDNS', 'ipv4.ignore-auto-dns', invert: true)
    boolean('PEERROUTES', 'ipv4.ignore-auto-routes', invert: true)
    @properties['ipv4.may-fail'] = !flag('IPV4_FAILURE_FATAL', false)
  end

  def ipv6
    addresses = [take('IPV6ADDR'), *take('IPV6ADDR_SECONDARIES', '').split].compact
    enabled = flag('IPV6INIT', true)
    disabled = flag('IPV6_DISABLED', false)
    forwarding = flag('IPV6FORWARDING', false)
    autoconf = flag('IPV6_AUTOCONF', !forwarding)
    dhcp = flag('DHCPV6C', false)
    method = if disabled
               'disabled'
             elsif !enabled
               'ignore'
             elsif autoconf
               'auto'
             elsif dhcp
               'dhcp'
             elsif addresses.empty?
               'link-local'
             else
               'manual'
             end
    @properties['ipv6.method'] = method
    @properties['ipv6.addresses'] = addresses.join(',') unless addresses.empty?
    copy('IPV6_DEFAULTGW', 'ipv6.gateway')
    copy('IPV6_ROUTE_METRIC', 'ipv6.route-metric')
    copy('IPV6_ROUTE_TABLE', 'ipv6.route-table')
    copy('IPV6_DNS_PRIORITY', 'ipv6.dns-priority')
    copy('IPV6_DHCP_TIMEOUT', 'ipv6.dhcp-timeout')
    copy('DHCPV6_HOSTNAME', 'ipv6.dhcp-hostname')
    copy('IPV6_ADDR_GEN_MODE', 'ipv6.addr-gen-mode')
    boolean('IPV6_DEFROUTE', 'ipv6.never-default', invert: true)
    boolean('IPV6_PEERDNS', 'ipv6.ignore-auto-dns', invert: true)
    boolean('IPV6_PEERROUTES', 'ipv6.ignore-auto-routes', invert: true)
    @properties['ipv6.may-fail'] = !flag('IPV6_FAILURE_FATAL', false)
  end

  def dns
    @config.keys.grep(/\ADNS\d+\z/).sort_by { |key| key.delete_prefix('DNS').to_i }.each do |key|
      address = take(key)
      property = address.include?(':') ? 'ipv6.dns' : 'ipv4.dns'
      @properties[property] = [@properties[property], address].compact.join(',')
    end
    domains = take('DOMAIN')
    @properties['ipv4.dns-search'] = domains.split.join(',') if domains
    domains6 = take('IPV6_DOMAIN')
    @properties['ipv6.dns-search'] = domains6.split.join(',') if domains6
  end
end

# Preserve the extension helpers' ifcfg-style arguments on EL10. NetworkManager
# validates and serializes the equivalent keyfile without a running daemon.
class DiscoveryKeyfile
  include DiscoveryIPSettings

  def initialize(input)
    @config = {}
    input.each_line do |line|
      next if line.strip.empty? || line.lstrip.start_with?('#')

      key, value = line.strip.split('=', 2)
      raise ArgumentError, "Invalid network setting: #{line.strip}" unless value && key.match?(/\A[A-Z][A-Z0-9_]*\z/)

      @config[key] = Shellwords.split(value).join(' ')
    end
    @properties = {}
  end

  def take(key, default = nil)
    @config.key?(key) ? @config.delete(key) : default
  end

  def flag(key, default = nil)
    value = take(key, default)
    return value if [true, false, nil].include?(value)
    return true if ['yes', 'true', '1'].include?(value.downcase)
    return false if ['no', 'false', '0'].include?(value.downcase)

    raise ArgumentError, "Invalid boolean #{key}=#{value}"
  end

  def copy(key, property)
    value = take(key)
    @properties[property] = value if value && !value.empty?
  end

  def boolean(key, property, invert: false)
    value = flag(key)
    @properties[property] = invert ? !value : value unless value.nil?
  end

  def connection
    type = take('TYPE', 'Ethernet').downcase
    raise ArgumentError, "Unsupported connection type: #{type}" unless ['ethernet', 'bond'].include?(type)
    raise ArgumentError, 'NM_CONTROLLED=no requires an unmanaged-device configuration' unless flag('NM_CONTROLLED', true)

    @properties['connection.type'] = type == 'ethernet' ? '802-3-ethernet' : type
    @properties['connection.interface-name'] = take('DEVICE')
    @properties['connection.id'] = take('NAME', @properties['connection.interface-name'])
    @properties['connection.autoconnect'] = flag('ONBOOT', true)
    copy('UUID', 'connection.uuid')
    copy('AUTOCONNECT_PRIORITY', 'connection.autoconnect-priority')
    copy('HWADDR', '802-3-ethernet.mac-address')
    copy('MACADDR', '802-3-ethernet.cloned-mac-address')
    copy('MTU', '802-3-ethernet.mtu')
    take('BONDING_MASTER')
    options = take('BONDING_OPTS')
    @properties['bond.options'] = options.split.join(',') if options
    @controller = take('MASTER')
    return unless flag('SLAVE', false) || @controller
    raise ArgumentError, 'A bond member requires MASTER' unless @controller

    @properties['connection.controller'] = @controller
    @properties['connection.port-type'] = 'bond'
  end

  def write(name)
    raise ArgumentError, "Invalid network profile filename: #{name}" unless name.match?(/\A[\w.:-]+\z/)

    connection
    ipv4
    ipv6
    dns
    raise ArgumentError, "Unsupported ifcfg settings: #{@config.keys.join(', ')}" unless @config.empty?

    # Bond members have no independent IP configuration.
    @properties.reject! { |key, _| key.start_with?('ipv4.', 'ipv6.') } if @controller
    ['ipv4', 'ipv6'].each do |family|
      next unless ['disabled', 'ignore'].include?(@properties["#{family}.method"])

      @properties.reject! { |key, _| key.start_with?("#{family}.") && key != "#{family}.method" }
    end
    args = @properties.flat_map { |key, value| [key, value.to_s] }
    content, error, status = Open3.capture3('nmcli', '--offline', 'connection', 'add', *args)
    raise ArgumentError, error unless status.success?

    directory = '/etc/NetworkManager/system-connections'
    Tempfile.create('.fdi-', directory) do |file|
      file.chmod(0o600)
      file.write(content)
      file.flush
      File.rename(file.path, "#{directory}/#{name}.nmconnection")
    end
  end
end

begin
  DiscoveryKeyfile.new($stdin).write(ARGV.fetch(0))
rescue ArgumentError => e
  warn "Cannot configure discovery network: #{e.message}"
  exit 1
end
