def screen_welcome pipeline
  text_help, tw, th = Newt.reflow_text(_('Select Manual to select primary interface, configure network (no DHCP required), setup server credentials, add custom facts and trigger auto-provisioning via Discovery rules. This will lead to kernel reload (kexec) into installer. Select DHCP to select primary interface and proceed with DHCP configuration and standard discovery without any custom facts. This will reboot the host once the system is provisioned either manually or via Discovery rules.'), 60, 5, 5)
  t_welcome = Newt::Textbox.new(-1, -1, tw, th, Newt::FLAG_WRAP)
  t_welcome.set_text(text_help)

  b_discover = Newt::Button.new(-1, -1, _("Discover node"))
  b_image = Newt::Button.new(-1, -1, _("Image transfer"))
  b_status = Newt::Button.new(-1, -1, _("Status screen"))

  main_grid = Newt::Grid.new(1, 2)
  but_grid = Newt::Grid.new(3, 1)

  but_grid.set_field(0, 0, Newt::GRID_COMPONENT, b_discover, 0, 0, 0, 0, 0, 0)
  but_grid.set_field(1, 0, Newt::GRID_COMPONENT, b_image, 0, 0, 0, 0, 0, 0)
  but_grid.set_field(2, 0, Newt::GRID_COMPONENT, b_status, 0, 0, 0, 0, 0, 0)

  main_grid.set_field(0, 0, Newt::GRID_COMPONENT, t_welcome, 0, 0, 0, 1, 0, 0)
  main_grid.set_field(0, 1, Newt::GRID_SUBGRID, but_grid, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.wrapped_window(_("Welcome to PXE-less provisioning"))

  f = Newt::Form.new
  f.add(t_welcome, b_discover, b_image, b_status)
  answer = f.run()
  if answer == b_status
    pipeline.append :screen_status
    pipeline.data.status_text = generate_info(_('PXE-less mode'))
  elsif answer == b_image
    pipeline.append :screen_primary_iface
    pipeline.append :screen_image_mode
    pipeline.data.title = _("Transfer interface")
    pipeline.data.message = _("Select primary (provisioning) network interface with connection to server or proxy:")
    pipeline.data.on_ok = :screen_image
    pipeline.data.on_cancel = :screen_welcome
  elsif answer == b_discover
    pipeline.append :screen_primary_iface
    pipeline.append :screen_foreman
    pipeline.data.dhcp = false
  else
    pipeline.append :quit
  end
end
