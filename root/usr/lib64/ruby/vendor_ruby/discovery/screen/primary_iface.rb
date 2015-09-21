def screen_primary_iface dhcp = false
  width = 60
  t_desc = Newt::Textbox.new(-1, -1, width, 3, Newt::FLAG_WRAP)
  t_desc.set_text "Select primary (provisioning) network interface with connection to Foreman server:"
  lb_ifaces = Newt::Listbox.new(-1, -1, 10, Newt::FLAG_SCROLL)
  b_select = Newt::Button.new(-1, -1, "Select")
  b_cancel = Newt::Button.new(-1, -1, "Cancel")
  lb_ifaces.set_width(width)

  bootif = normalize_mac(cmdline('BOOTIF'))
  preselectedif = normalize_mac(cmdline('fdi.pxmac'))
  log_msg "Building net interfaces TUI (bootif=#{bootif})"
  ix = 0
  #if_names = {}
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
    #if_names[mac] = name
  end

  main_grid = Newt::Grid.new(1, 3)
  but_grid = Newt::Grid.new(2, 1)

  but_grid.set_field(0, 0, Newt::GRID_COMPONENT, b_select, 0, 0, 0, 0, 0, 0)
  but_grid.set_field(1, 0, Newt::GRID_COMPONENT, b_cancel, 0, 0, 0, 0, 0, 0)

  main_grid.set_field(0, 0, Newt::GRID_COMPONENT, t_desc, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.set_field(0, 1, Newt::GRID_COMPONENT, lb_ifaces, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.set_field(0, 2, Newt::GRID_SUBGRID, but_grid, 0, 1, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.wrapped_window("Primary interface")

  f = Newt::Form.new
  if preselectedif
    f.add(b_select, b_cancel, t_desc, lb_ifaces)
  else
    f.add(t_desc, lb_ifaces, b_select, b_cancel)
  end
  answer = f.run()
  if answer == b_select
    primary_mac = lb_ifaces.get_current_as_string
    if dhcp
      action = Proc.new { configure_network false, primary_mac }
      [:screen_info, action, "Configuring network via DHCP. This operation can take several minutes to complete.", "Unable to bring network via DHCP",
        [:screen_foreman, primary_mac, nil, cmdline('proxy.url'), cmdline('proxy.type'), true],
        [:screen_network, primary_mac]]
    else
      detect_ip, detect_gw, detect_dns = detect_ipv4_credentials('primary')
      [:screen_network, primary_mac, cmdline('fdi.pxip', detect_ip), cmdline('fdi.pxgw', detect_gw), cmdline('fdi.pxdns', detect_dns)]
    end
  elsif answer == b_cancel
    :screen_welcome
  end
end
