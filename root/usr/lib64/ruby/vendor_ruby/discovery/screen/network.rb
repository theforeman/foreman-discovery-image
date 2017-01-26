def screen_network pipeline
  ip = cmdline('fdi.pxip', pipeline.data.primary_ip || '')
  gw = cmdline('fdi.pxgw', pipeline.data.primary_gw || '')
  dns = cmdline('fdi.pxdns', pipeline.data.primary_dns || '')
  Newt::Screen.centered_window(49, 20, _("Network configuration"))
  f = Newt::Form.new
  t_desc = Newt::Textbox.new(2, 2, 44, 6, Newt::FLAG_WRAP)
  t_desc.set_text _("Provide network configuration for the selected primary interface. Use CIDR netmask notation (e.g. 192.168.1.1/24) for the IP address.")
  l_ip = Newt::Label.new(2, 8, _("IPv4 Address:"))
  l_gw = Newt::Label.new(2, 10, _("IPv4 Gateway:"))
  l_dns = Newt::Label.new(2, 12, _("IPv4 DNS:"))
  t_ip = Newt::Entry.new(16, 8, ip, 30, 0)
  t_gw = Newt::Entry.new(16, 10, gw, 30, 0)
  t_dns = Newt::Entry.new(16, 12, dns, 30, 0)
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
    pipeline.data.primary_ip = t_ip.get
    pipeline.data.primary_gw = t_gw.get
    pipeline.data.primary_dns = t_dns.get
    begin
      IPAddr.new(pipeline.data.primary_ip); IPAddr.new(pipeline.data.primary_gw); IPAddr.new(pipeline.data.primary_dns)
    rescue Exception
      Newt::Screen.win_message(_("Invalid IP"), _("OK"), _("Provide valid CIDR ipaddress with a netmask, gateway and one DNS server"))
      pipeline.prepend :screen_network
      return
    end
    pipeline.append :screen_info
    # the screen after will be picked depedning on the return value of the next screen (0 or 1)
    pipeline.append [:screen_foreman, :screen_network]
    pipeline.data.action_proc = Proc.new { configure_network false, pipeline.data.primary_mac, nil, nil, nil, pipeline.data.vlan_id }
    pipeline.data.message = _("Configuring network. This operation can take several minutes to complete.")
    pipeline.data.error_message = _("Unable to bring network")
  else
    :screen_welcome
  end
end
