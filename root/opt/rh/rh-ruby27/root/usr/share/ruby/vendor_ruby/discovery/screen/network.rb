def screen_network mac, vlan_id, ip = cmdline('fdi.pxip', ''), gw = cmdline('fdi.pxgw', ''), dns = cmdline('fdi.pxdns', '')
  Newt::Screen.centered_window(75, 20, _("Network configuration"))
  f = Newt::Form.new
  t_desc = Newt::Textbox.new(2, 2, 70, 6, Newt::FLAG_WRAP)
  t_desc.set_text _("Provide network configuration for the selected primary interface. Use CIDR netmask notation (e.g. 192.168.1.1/24) for the IPv4 or IPv6 address.")
  l_ip = Newt::Label.new(2, 8, _("Address:"))
  l_gw = Newt::Label.new(2, 10, _("Gateway:"))
  l_dns = Newt::Label.new(2, 12, _("DNS:"))
  t_ip = Newt::Entry.new(16, 8, ip, 55, Newt::FLAG_SCROLL)
  t_gw = Newt::Entry.new(16, 10, gw, 55, Newt::FLAG_SCROLL)
  t_dns = Newt::Entry.new(16, 12, dns, 55, Newt::FLAG_SCROLL)
  b_ok = Newt::Button.new(24, 15, _("Next"))
  b_cancel = Newt::Button.new(36, 15, _("Cancel"))
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
      Newt::Screen.win_message(_("Invalid IP"), _("OK"), _("Provide valid CIDR ipaddress with a netmask, gateway and one DNS server"))
      return [:screen_network, mac, vlan_id, ip, gw, dns]
    end
    action = Proc.new { configure_network true, mac, ip, gw, dns, vlan_id }
    [:screen_info, action, _("Configuring network. This operation can take several minutes to complete."), _("Unable to bring up network"),
      [:screen_foreman, mac, gw],
      [:screen_network, mac, vlan_id, ip, gw, dns]]
  else
    :screen_welcome
  end
end
