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
    command("nm-configure primary-static '#{mac}' '#{ip}' '#{gw}' '#{dns}' '#{vlan}'")
  else
    command("nm-configure primary '#{mac}' '#{vlan}'")
  end
  wait = cmdline('fdi.nmwait', 120)
  command("nmcli -w #{wait} connection reload", false)
  up_result = command("nmcli -w #{wait} connection up primary", false)
  command("nm-online -s -q --timeout=#{wait}")
  # wait for IPv4, generate SSL self-signed cert and start proxy
  command("systemctl start foreman-proxy") && up_result
end

def perform_upload proxy_url, proxy_type, custom_facts
  upload proxy_url, proxy_type, custom_facts
rescue => e
  error_box("Unable to upload facts", e)
end

def new_custom_facts mac
  ip_cidr, gw, dns = detect_ipv4_credentials('primary')
  ip = ip_cidr.split('/').first
  mask = IPAddr.new(ip_cidr).inspect.scan(/\d+.\d+.\d+.\d+\/\d+.\d+.\d+.\d+/).first.split('/').last
  {
    'discovery_kexec' => command("kexec --version"),
    'discovery_ip_cidr' => ip_cidr,
    'discovery_ip' => ip,
    'discovery_netmask' => mask,
    'discovery_gateway' => gw,
    'discovery_dns' => dns,
    'discovery_bootif' => mac,
  }
rescue => e
  log_exception e
  {}
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
        delay = cmdline('fdi.countdown', 10)
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
