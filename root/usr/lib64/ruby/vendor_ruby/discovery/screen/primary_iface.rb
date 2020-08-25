def screen_primary_iface pipeline
  raise "Primary interface selection requires a sucessive screen" if pipeline.size < 1
  bootif = normalize_mac(cmdline('BOOTIF'))
  preselectedif = normalize_mac(cmdline('fdi.pxmac'))
  vlanid = cmdline('fdi.vlan.primary', '')

  width = 60
  t_desc = Newt::Textbox.new(-1, -1, width, 3, Newt::FLAG_WRAP)
  t_desc.set_text(pipeline.data.message || _("Select primary (provisioning) network interface with connection to server or proxy:"))
  lb_ifaces = Newt::Listbox.new(-1, -1, 7, Newt::FLAG_SCROLL)
  l_vlan = Newt::Label.new(-1, -1, "VLAN ID: ")
  t_vlan = Newt::Entry.new(-1, -1, vlanid, 4, 0)
  b_ok_dhcp = Newt::Button.new(-1, -1, _("DHCP"))
  b_ok_manual = Newt::Button.new(-1, -1, _("Manual"))
  b_cancel = Newt::Button.new(-1, -1, _("Cancel"))
  lb_ifaces.set_width(width)
  names = {}

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
    names[mac] = name
    lb_ifaces.set_current ix if booted || preselected
    ix = ix + 1
  end

  main_grid = Newt::Grid.new(1, 3)
  but_grid = Newt::Grid.new(4, 1)
  vlan_grid = Newt::Grid.new(2, 1)

  vlan_grid.set_field(0, 0, Newt::GRID_COMPONENT, l_vlan, 0, 0, 0, 0, 0, 0)
  vlan_grid.set_field(1, 0, Newt::GRID_COMPONENT, t_vlan, 0, 0, 0, 0, 0, 0)

  but_grid.set_field(0, 0, Newt::GRID_COMPONENT, b_ok_dhcp, 0, 0, 0, 0, 0, 0)
  but_grid.set_field(1, 0, Newt::GRID_COMPONENT, b_ok_manual, 0, 0, 0, 0, 0, 0)
  but_grid.set_field(2, 0, Newt::GRID_COMPONENT, b_cancel, 0, 0, 0, 0, 0, 0)
  but_grid.set_field(3, 0, Newt::GRID_SUBGRID, vlan_grid, 0, 0, 0, 0, 0, 0)

  main_grid.set_field(0, 0, Newt::GRID_COMPONENT, t_desc, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.set_field(0, 1, Newt::GRID_COMPONENT, lb_ifaces, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.set_field(0, 2, Newt::GRID_SUBGRID, but_grid, 0, 1, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.wrapped_window(pipeline.data.title || _("Primary interface"))

  f = Newt::Form.new
  if preselectedif
    f.add(b_ok_dhcp, b_ok_manual, b_cancel, l_vlan, t_vlan, t_desc, lb_ifaces)
  else
    f.add(t_desc, lb_ifaces, b_ok_dhcp, b_ok_manual, b_cancel, l_vlan, t_vlan)
  end
  answer = f.run()
  if answer == b_cancel
    pipeline.cancel pipeline.data.on_cancel
    return
  end
  pipeline.data.primary_mac = lb_ifaces.get_current_as_string
  pipeline.data.primary_name = names[pipeline.data.primary_mac]
  pipeline.data.vlan_id = t_vlan.get
  if answer == b_ok_dhcp
    # the screen after will be picked depedning on the return value of the next screen (0 or 1)
    pipeline.append [pipeline.next, :screen_primary_iface]
    # and set the very next screen
    pipeline.prepend :screen_info
    pipeline.data.action_proc = Proc.new { configure_network false, pipeline.data.primary_mac, nil, nil, nil, pipeline.data.vlan_id }
    pipeline.data.message = _("Configuring network via DHCP. This operation can take several minutes to complete.")
    pipeline.data.error_message = _("Unable to bring network via DHCP")
  else # manual
    detect_ip, detect_gw, detect_dns = detect_ipv4_credentials('primary')
    pipeline.prepend :screen_network
    pipeline.data.manual_ip = cmdline('fdi.pxip', detect_ip)
    pipeline.data.manual_gw = cmdline('fdi.pxgw', detect_gw)
    pipeline.data.manual_dns = cmdline('fdi.pxdns', detect_dns)
  end
end
