require "newt"
require "discovery"
require "facter"
require "ipaddr"

def fdi_version file = 'VERSION'
  return 'GIT' unless File.exist?("/usr/share/fdi/#{file}")
  IO.read("/usr/share/fdi/#{file}").chomp
end

def fdi_release file = 'RELEASE'
  fdi_version file
end

def enable_root_account(pass)
  command("echo 'root:#{pass}' | chpasswd && systemctl restart sshd.service")
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

def command(cmd, fail_on_error = true)
  log_msg "TUI executing: #{cmd}"
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
    command("systemctl start discovery-register.service")
  end
end

def configure_network static, mac, ip=nil, gw=nil, dns=nil
  command("systemctl stop foreman-proxy")
  if static
    command("nm-configure primary-static '#{mac}' '#{ip}' '#{gw}' '#{dns}'")
  else
    command("nm-configure primary '#{mac}'")
  end
  command("nmcli connection reload")
  command("nmcli connection down primary")
  result = command("nmcli connection up primary", false)
  # restarting proxy with regenerated SSL self-signed cert
  command("systemctl start foreman-proxy") if result
  result
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
end

def detect_first_nic_with_link
  log_debug "Trying to guess the first NICs with link, fdi.pxmac was NOT provided"
  mac = nil
  Dir.glob('/sys/class/net/*').sort.each do |ifn|
    name = File.basename ifn
    next if name == "lo"
    mac = File.read("#{ifn}/address").chomp rescue "??:??:??:??:??:??"
    link = File.read("#{ifn}/carrier").chomp == "1" rescue false
    if link
      log_debug "Interface with link found: #{name}=#{mac}"
      break
    end
  end
  mac
end

log_msg "Kernel opts: #{cmdline}"

def main_loop
  Signal.trap("TERM") { cleanup }
  Signal.trap("INT") { cleanup }
  Signal.trap("HUP") do
    Newt::Screen.refresh
  end

  Newt::Screen.new
  Newt::Screen.push_helpline("Foreman Discovery Image v#{fdi_version} (#{fdi_release})")

  if cmdline('BOOTIF')
    # Booted via PXE
    active_screen = :screen_countdown
  else
    # Booted from ISO
    if cmdline('fdi.pxauto')
      # Unattended PXE-less provisioning
      log_debug "Unattended provisioning started"
      proxy_url = cmdline('proxy.url') || error_box("Option proxy.url was not provided, cannot continue")
      proxy_url = URI.parse(proxy_url) rescue error_box("Unable to parse proxy.url URI: #{proxy_url}")
      proxy_type = cmdline('proxy.type') || error_box("Option proxy.type was not provided, cannot continue")
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
        log_debug "Unattended facts collection started"
        facts = new_custom_facts(mac)
        [1..9].each do |n|
          if (fact_name = cmdline("fdi.pxfactname#{n}"))
            fact_value = cmdline("fdi.pxfactvalue#{n}")
            facts[fact_name] = fact_value
          end
        end
        log_debug "Unattended facts collection finished"
        log_debug "Unattended facts upload started"
        result = upload(proxy_url, proxy_type, facts)
        log_debug "Unattended facts upload finished, result: #{result}"
        result
      end
      active_screen = [:screen_info, action,
        "Performing unattended provisioning via NIC #{mac} (provided credentials: ip=#{ip} gw=#{gw} dns=#{dns}) and sending facts to #{proxy_url} of endpoint type #{proxy_type}. This can take a while...",
        "Unattended provisioning failed: unable to upload facts. Check your network credentials.",
        [:screen_status, generate_info('Unattended fact upload OK - awaiting kexec')],
        [:screen_status, generate_info('Unattended fact upload FAILED - check logs')]]
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
  error_box("Fatal error - investigate journal", e) unless e.is_a? SystemExit
ensure
  cleanup
end
