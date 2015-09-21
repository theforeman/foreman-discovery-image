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
  if extra_msg.is_a? Exception
    backtrace = (extra_msg.to_s + "\n" + extra_msg.backtrace.join("\n")) rescue 'N/A'
    log_err backtrace
  end
  log_err extra_msg
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
  true
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
end

def cleanup
  Newt::Screen.finish
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

  if cmdline('fdi.pxauto')
    # automated pxeless discovery via kernel command line options
    mac = cmdline('fdi.pxmac')
    ip = cmdline('fdi.pxip')
    gw = cmdline('fdi.pxgw')
    dns = cmdline('fdi.pxdns')
    configure_network true, mac, ip, gw, dns
    proxy_url = cmdline('proxy.url')
    proxy_url = cmdline('proxy.type')
    facts = new_custom_facts(mac)
    [1..9].each do |n|
      if (fact_name = cmdline("fdi.pxfactname#{n}"))
        fact_value = cmdline("fdi.pxfactvalue#{n}")
        facts[fact_name] = fact_value
      end
    end
    if perform_upload(proxy_url, proxy_type, custom_facts)
      [:screen_status, generate_info('AWAITING KEXEC INTO INSTALLER')]
    else
      error_box("Unable to send facts", "Automated fact upload failed")
    end
  end

  if cmdline('BOOTIF')
    func = :screen_countdown
  else
    # the image was booted from ISO directly
    func = :screen_welcome
  end
  while ! [:quit].include? func
    if func.is_a?(Array)
      log_debug "Entering #{func[0]}"
      func = send(*func)
    else
      log_debug "Entering #{func}"
      func = send(func)
    end
    Newt::Screen.pop_window()
  end
rescue Exception => e
  error_box("Fatal error - investigate journal", e) unless e.is_a? SystemExit
ensure
  cleanup
end
