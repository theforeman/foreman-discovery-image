def screen_welcome
  text_help, tw, th = Newt.reflow_text(<<EOT, 60, 5, 5)
Select Manual network setup to select primary interface, configure network (no DHCP required), \
setup server credentials, add custom facts and trigger auto-provisioning \
via Discovery rules. This will lead to kernel reload (kexec) into installer. \
Select Discover with DHCP to select primary interface and proceed with DHCP configuration \
and standard discovery without any custom facts. This will reboot the host once the system \
is provisioned either manually or via Discovery rules.
EOT
  t_welcome = Newt::Textbox.new(-1, -1, tw, th, Newt::FLAG_WRAP)
  t_welcome.set_text(text_help)

  b_proceed = Newt::Button.new(-1, -1, "Manual network setup")
  b_discover = Newt::Button.new(-1, -1, "Discover with DHCP")

  main_grid = Newt::Grid.new(1, 2)
  but_grid = Newt::Grid.new(2, 1)

  but_grid.set_field(0, 0, Newt::GRID_COMPONENT, b_proceed, 0, 0, 0, 0, 0, 0)
  but_grid.set_field(1, 0, Newt::GRID_COMPONENT, b_discover, 0, 0, 0, 0, 0, 0)

  main_grid.set_field(0, 0, Newt::GRID_COMPONENT, t_welcome, 0, 0, 0, 1, 0, 0)
  main_grid.set_field(0, 1, Newt::GRID_SUBGRID, but_grid, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.wrapped_window("Manual/PXE-less provisioning workflow")

  f = Newt::Form.new
  f.add(t_welcome, b_proceed, b_discover)
  answer = f.run()
  if answer == b_discover
    [:screen_primary_iface, true]
  elsif answer == b_proceed
    :screen_primary_iface
  else
    :quit
  end
end
