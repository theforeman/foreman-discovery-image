require "newt"
require "discovery"
require "facter"
require "ipaddr"
require "fast_gettext"

def fdi_version file = 'VERSION'
  return 'GIT' unless File.exist?("/usr/share/fdi/#{file}")
  IO.read("/usr/share/fdi/#{file}").chomp
end

def fdi_release file = 'RELEASE'
  fdi_version file
end

def enable_root_account(pass)
  command("sed -i 's/^.*PermitRootLogin.*$/PermitRootLogin yes/' '/etc/ssh/sshd_config'", false, false)
  command("sed -i 's/^.*PasswordAuthentication.*$/PasswordAuthentication yes/' '/etc/ssh/sshd_config'", false, false)
  command("echo 'root:#{pass}' | chpasswd && systemctl restart sshd.service", false, false)
end

def error_box(msg, extra_msg = nil)
  log_err msg
  log_err extra_msg
  backtrace = log_exception extra_msg
  Newt::Screen.centered_window(74, 20, "Fatal error")
  f = Newt::Form.new
  t_desc = Newt::Textbox.new(1, 1, 70, 13, Newt::FLAG_SCROLL)
  random_pass = (1...10).map { (65 + rand(26)).chr }.join
  t_desc.set_text "#{msg}:\n#{extra_msg}\n\n#{backtrace}\n\n" +
  "Once OK button is pressed, and root account will be unlocked\n" +
  "with the following random password:\n\n" +
  "   #{random_pass}\n\n" +
  "It is possible to use third console to login and investigate\n" +
  "via journalctl and discovery-debug commands. "
  b_ok = Newt::Button.new(66, 15, "OK")
  f.add(b_ok, t_desc)
  f.run
  enable_root_account(random_pass)
  exit(1)
end

def command(cmd, fail_on_error = true, send_to_syslog = true)
  log_msg("TUI executing: #{cmd}") if send_to_syslog
  # do not run real commands in development (non-image) environment
  return true if fdi_version == 'GIT'
  output = `#{cmd} 2>&1`
  if $? != 0
    log_msg("Command returned #{$?} and output was: #{output}") if send_to_syslog
    if fail_on_error
      error_box("Command failed: #{cmd}", output)
    else
      return false
    end
  end
  output
end

def debug_value val
  Newt::Screen.win_message("DEBUG", "OK", val.inspect)
end

def wrap(s, width=78)
  s.gsub(/(.{1,#{width}})(\s+|\Z)/, "\\1\n")
end

def disable_tftp_extensions
  ['path', 'service'].each do |unit|
    if File.exist? "/etc/systemd/system/discovery-fetch-extensions.#{unit}"
      command("systemctl disable discovery-fetch-extensions.#{unit}")
    end
  end
end

def start_discovery_service
  if File.exist? "/etc/systemd/system/discovery-register.service"
    command("systemctl restart discovery-register.service")
  end
end

def configure_network static, mac, ip=nil, gw=nil, dns=nil, vlan=nil
  command("systemctl stop foreman-proxy", false)
  if static
    if IPAddr.new(ip).ipv6?
      cmd = "primary-static6"
    else
      cmd = "primary-static"
    end
    command("nm-configure #{cmd} '#{mac}' '#{ip}' '#{gw}' '#{dns}' '#{vlan}'")
  else
    command("nm-configure primary '#{mac}' '#{vlan}'")
  end
  wait = cmdline('fdi.nmwait', 120)
  command("nmcli -w #{wait} connection reload", false)
  sleep 2
  up_result = command("nmcli -w #{wait} connection up primary", false)
  sleep 2
  command("nm-online -s -q --timeout=#{wait}")
  # wait for IPv4, generate SSL self-signed cert and start proxy
  command("systemctl start foreman-proxy") && up_result
end

def perform_upload proxy_url, proxy_type, custom_facts
  upload proxy_url, proxy_type, custom_facts
rescue => e
  error_box("Unable to upload facts", e)
end

# Collect fact necessary for the kexec
# See the redhat_kexec.erb template for more details
def new_custom_facts(mac)
  custom_facts = {}
  custom_facts['discovery_bootif'] = mac
  custom_facts['discovery_kexec'] = command('kexec --version')

  cred_cidr6, gw6, dns6 = detect_ipv6_credentials('primary')
  cidr6 = IPAddr.new(cred_cidr6) if cred_cidr6

  # IPv6 is prefered over the IPv4 in dual stack environment
  # and if the IPv6 is not link-local
  if cidr6 && !cidr6.link_local?
    ip6 = cred_cidr6.split('/').first
    mask6 = cidr6.inspect.split('/').last[0..-2]

    custom_facts['discovery_ip_cidr'] = cred_cidr6
    custom_facts['discovery_ip'] = ip6
    custom_facts['discovery_netmask'] = mask6
    custom_facts['discovery_gateway'] = gw6
    custom_facts['discovery_dns'] = dns6

    return custom_facts
  end

  cred_cidr4, gw4, dns4 = detect_ipv4_credentials('primary')
  ip4 = cred_cidr4.split('/').first
  cidr4 = IPAddr.new(cred_cidr4)
  mask4 = cidr4.inspect.split('/').last[0..-2]

  custom_facts['discovery_ip_cidr'] = cred_cidr4
  custom_facts['discovery_ip'] = ip4
  custom_facts['discovery_netmask'] = mask4
  custom_facts['discovery_gateway'] = gw4
  custom_facts['discovery_dns'] = dns4
  custom_facts
rescue StandardError => e
  log_exception e
  custom_facts
end

def cleanup
  Newt::Screen.finish
  exit 0
end

log_msg "Kernel opts: #{cmdline}"

# fast_gettext initialization
begin
  FastGettext.add_text_domain('foreman-discovery-image',
    :path => File.exists?('/usr/share/locale/fdi') ? '/usr/share/locale/fdi' : 'root/usr/share/locale/fdi',
    :type => :po,
    :ignore_fuzzy => true,
    :report_warning => false)
  FastGettext.text_domain = 'foreman-discovery-image'
  selected_locale = cmdline('locale')
  FastGettext.locale = selected_locale if selected_locale
rescue Exception => e
  error_box("Unable to initialize gettext: #{e}", e) unless e.is_a? SystemExit
end
include FastGettext::Translation

def main_loop
  Signal.trap("TERM") { cleanup }
  Signal.trap("INT") { cleanup }
  Signal.trap("HUP") do
    Newt::Screen.refresh
  end

  Newt::Screen.new
  mode = if File.exists?("/sys/firmware/efi/")
           "UEFI"
         else
           "BIOS"
         end
  driver = `cat /proc/fb`.strip.tr("\n", ' ')
  driver = "NO-FB" if driver.empty?
  Newt::Screen.push_helpline(_("Foreman Discovery Image") + " v#{fdi_version} (#{fdi_release}) #{RUBY_PLATFORM} #{mode} #{driver}")

  if cmdline('BOOTIF')
    # Booted via PXE
    active_screen = :screen_countdown
  else
    # Booted from ISO
    if cmdline('fdi.pxauto')
      # Unattended PXE-less provisioning
      log_debug "Unattended provisioning started"
      proxy_url = cmdline('proxy.url') || error_box(_("Option proxy.url was not provided, cannot continue"))
      proxy_url = URI.parse(proxy_url) rescue error_box(_("Unable to parse proxy.url URI: %s") % proxy_url)
      proxy_type = cmdline('proxy.type') || error_box(_("Option proxy.type was not provided, cannot continue"))
      log_debug "proxy.url=#{proxy_url} proxy.type=#{proxy_type}"
      mac = cmdline('fdi.pxmac') || detect_first_nic_with_link
      ip = cmdline('fdi.pxip')
      gw = cmdline('fdi.pxgw')
      dns = cmdline('fdi.pxdns')
      action = Proc.new do
        log_debug "Unattended network configuration started"
        if ip && gw
          log_debug "Configuring #{mac} with static info: ip=#{ip} gw=#{gw} dns=#{dns}"
          status = configure_network true, mac, ip, gw, dns
        else
          log_debug "Configuring #{mac} with DHCP (pxip or pxgw were not provided)"
          status = configure_network false, mac
        end
        log_debug "Unattended network configuration finished, result: #{status}"
        delay = cmdline('fdi.countdown', 45).to_i rescue 45
        log_debug "Delay for network initialization: #{delay} seconds"
        sleep delay
        facts = new_custom_facts(mac)
        log_debug "Unattended facts upload started"
        result = upload(proxy_url, proxy_type, facts)
        log_debug "Unattended facts upload finished, result: #{result}"
        result
      end
      active_screen = [:screen_info, action,
        (_("Performing unattended provisioning via NIC %s, please wait.") % mac) + " (ip=#{ip} gw=#{gw} dns=#{dns}, url=#{proxy_url} [#{proxy_type}])",
        _("Unattended provisioning failed: unable to upload facts. Check your network credentials."),
        [:screen_status, generate_info(_('Unattended fact upload OK - awaiting kexec'))],
        [:screen_status, generate_info(_('Unattended fact upload FAILED - check logs'))]]
    else
      # Attended PXE-less provisioning
      active_screen = :screen_welcome
    end
  end
  while ! [:quit].include? active_screen
    if active_screen.is_a?(Array)
      log_debug "Entering #{active_screen[0]}"
      active_screen = send(*active_screen)
    else
      log_debug "Entering #{active_screen}"
      active_screen = send(active_screen)
    end
    Newt::Screen.pop_window()
  end
rescue Exception => e
  error_box(_("Fatal error - investigate journal"), e) unless e.is_a? SystemExit
ensure
  cleanup
end
