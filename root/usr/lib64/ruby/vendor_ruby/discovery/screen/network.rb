def screen_network mac, ip = cmdline('fdi.pxip', ''), gw = cmdline('fdi.pxgw', ''), dns = cmdline('fdi.pxdns', '')
  Newt::Screen.centered_window(49, 20, "Network configuration")
  f = Newt::Form.new
  t_desc = Newt::Textbox.new(2, 2, 44, 6, Newt::FLAG_WRAP)
  t_desc.set_text "Provide network configuration for the selected primary interface. " +
  "Use CIDR netmask notation (e.g. 192.168.1.1/24) for the IP address."
  l_ip = Newt::Label.new(2, 8, "IPv4 Address:")
  l_gw = Newt::Label.new(2, 10, "IPv4 Gateway:")
  l_dns = Newt::Label.new(2, 12, "IPv4 DNS:")
  t_ip = Newt::Entry.new(16, 8, ip, 30, 0)
  t_gw = Newt::Entry.new(16, 10, gw, 30, 0)
  t_dns = Newt::Entry.new(16, 12, dns, 30, 0)
  b_ok = Newt::Button.new(24, 15, "Next")
  b_cancel = Newt::Button.new(36, 15, "Cancel")
  items = [t_desc, l_ip, l_gw, l_dns, t_ip, t_gw, t_dns]
  if cmdline('fdi.pxip')
    f.add(b_ok, b_cancel, *items)
  else
    f.add(*items, b_ok, b_cancel)
  end
  answer = f.run
  if answer == b_ok
    ip = t_ip.get
    gw = t_gw.get
    dns = t_dns.get
    begin
      IPAddr.new(ip); IPAddr.new(gw); IPAddr.new(dns)
    rescue Exception => e
      Newt::Screen.win_message("Invalid IP", "OK", "Provide valid CIDR ipaddress with a netmask, gateway and one DNS server")
      return [:screen_network, mac, ip, gw, dns]
    end
    action = Proc.new { configure_network true, mac, ip, gw, dns }
    [:screen_info, action, "Configuring network via DHCP. This operation can take several minutes to complete.", "Unable to bring network via DHCP",
      [:screen_foreman, mac, gw],
      [:screen_network, mac, ip, gw, dns]]
  else
    :screen_welcome
  end
end
