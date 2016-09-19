def screen_primary_iface dhcp = false
  bootif = normalize_mac(cmdline('BOOTIF'))
  preselectedif = normalize_mac(cmdline('fdi.pxmac'))
  vlanid = cmdline('fdi.vlan.primary', '')

  width = 60
  t_desc = Newt::Textbox.new(-1, -1, width, 3, Newt::FLAG_WRAP)
  t_desc.set_text _("Select primary (provisioning) network interface with connection to server or proxy:")
  lb_ifaces = Newt::Listbox.new(-1, -1, 7, Newt::FLAG_SCROLL)
  l_vlan = Newt::Label.new(-1, -1, "VLAN ID:")
  t_vlan = Newt::Entry.new(-1, -1, vlanid, 10, Newt::FLAG_SCROLL)
  b_select = Newt::Button.new(-1, -1, _("Select"))
  b_cancel = Newt::Button.new(-1, -1, _("Cancel"))
  lb_ifaces.set_width(width)

  log_msg "Building net interfaces TUI (bootif=#{bootif})"
  ix = 0
  Dir.glob('/sys/class/net/*') do |ifn|
    name = File.basename ifn
    next if name == "lo"
    mac = File.read("#{ifn}/address").chomp rescue "??:??:??:??:??:??"
    link = File.read("#{ifn}/carrier").chomp == "1" rescue false
    mac = ' ' * 17 if mac == ''
    booted = (mac == bootif)
    preselected = (mac == preselectedif)
    log_msg "Device #{name} #{mac} link=#{link} booted=#{booted}"
    lb_ifaces.append "#{mac} #{name} #{' (link up)' if link} #{' (pxebooted)' if booted}", mac
    lb_ifaces.set_current ix if booted || preselected
    ix = ix + 1
  end

  main_grid = Newt::Grid.new(1, 4)
  but_grid = Newt::Grid.new(2, 1)
  vlan_grid = Newt::Grid.new(2, 1)

  but_grid.set_field(0, 0, Newt::GRID_COMPONENT, b_select, 0, 0, 0, 0, 0, 0)
  but_grid.set_field(1, 0, Newt::GRID_COMPONENT, b_cancel, 0, 0, 0, 0, 0, 0)

  vlan_grid.set_field(0, 0, Newt::GRID_COMPONENT, l_vlan, 0, 0, 0, 0, 0, 0)
  vlan_grid.set_field(1, 0, Newt::GRID_COMPONENT, t_vlan, 0, 0, 0, 0, 0, 0)

  main_grid.set_field(0, 0, Newt::GRID_COMPONENT, t_desc, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.set_field(0, 1, Newt::GRID_COMPONENT, lb_ifaces, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.set_field(0, 2, Newt::GRID_SUBGRID, vlan_grid, 0, 1, 0, 0, 0, 0)
  main_grid.set_field(0, 3, Newt::GRID_SUBGRID, but_grid, 0, 1, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.wrapped_window(_("Primary interface"))

  f = Newt::Form.new
  if preselectedif
    f.add(b_select, b_cancel, t_desc, lb_ifaces, l_vlan, t_vlan)
  else
    f.add(t_desc, lb_ifaces, l_vlan, t_vlan, b_select, b_cancel)
  end
  answer = f.run()
  if answer == b_select
    primary_mac = lb_ifaces.get_current_as_string
    vlan_id = t_vlan.get
    if dhcp
      action = Proc.new { configure_network false, primary_mac, nil, nil, nil, vlan_id }
      [:screen_info, action, _("Configuring network via DHCP. This operation can take several minutes to complete."), _("Unable to bring network via DHCP"),
        [:screen_foreman, primary_mac, nil, cmdline('proxy.url'), cmdline('proxy.type')],
        [:screen_network, primary_mac, vlan_id]]
    else
      detect_ip, detect_gw, detect_dns = detect_ipv4_credentials('primary')
      [:screen_network, primary_mac, vlan_id, cmdline('fdi.pxip', detect_ip), cmdline('fdi.pxgw', detect_gw), cmdline('fdi.pxdns', detect_dns)]
    end
  elsif answer == b_cancel
    :screen_welcome
  end
end
