def screen_image_mode pipeline
  b_next = Newt::Button.new(-1, -1, _("Next"))
  b_cancel = Newt::Button.new(-1, -1, _("Cancel"))

  width = 50
  t_desc = Newt::Textbox.new(-1, -1, width, 4, Newt::FLAG_WRAP)
  t_desc.set_text _("Select udpcast multicast tool (EXPERIMENTAL) or simple HTTP download to download or upload an image.")

  top_grid = Newt::Grid.new(1, 3)
  form_grid = Newt::Grid.new(1, 6)
  but_grid = Newt::Grid.new(3, 1)

  # set_field(column, row, type, value, pad_left, pad_top, pad_right, pad_bottom, anchor, flags)
  but_grid.set_field(0, 0, Newt::GRID_COMPONENT, b_next, 1, 0, 1, 0, 0, 0)
  but_grid.set_field(1, 0, Newt::GRID_COMPONENT, b_cancel, 1, 0, 1, 0, 0, 0)

  r_udpreciever = Newt::RadioButton.new(-1, -1, _("UDP reciever"), 1, nil)
  r_udpsender = Newt::RadioButton.new(-1, -1, _("UDP sender"), 0, r_udpreciever)
  r_http = Newt::RadioButton.new(-1, -1, _("HTTP(S) download"), 0, r_udpsender)
  ch_reboot = Newt::Checkbox.new(-1, -1, _("Reboot when done"), "*", " *")
  l_volume = Newt::Label.new(-1, -1, _("Target or source volume:"))
  e_volume = Newt::Entry.new(-1, -1, "/dev/null", 20, Newt::FLAG_SCROLL)

  form_grid.set_field(0, 0, Newt::GRID_COMPONENT, r_udpreciever, 0, 0, 1, 0, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(0, 1, Newt::GRID_COMPONENT, r_udpsender, 0, 0, 0, 0, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(0, 2, Newt::GRID_COMPONENT, r_http, 0, 0, 0, 0, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(0, 3, Newt::GRID_COMPONENT, ch_reboot, 0, 1, 0, 1, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(0, 4, Newt::GRID_COMPONENT, l_volume, 0, 0, 0, 0, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(0, 5, Newt::GRID_COMPONENT, e_volume, 0, 0, 0, 1, Newt::ANCHOR_LEFT, 0)

  top_grid.set_field(0, 0, Newt::GRID_COMPONENT, t_desc, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  top_grid.set_field(0, 1, Newt::GRID_SUBGRID, form_grid, 0, 0, 0, 0, 0, 0)
  top_grid.set_field(0, 2, Newt::GRID_SUBGRID, but_grid, 0, 0, 0, 0, 0, 0)

  top_grid.wrapped_window(_("Image transfer - mode"))

  f = Newt::Form.new
  f.add(t_desc, r_udpreciever, r_udpsender, r_http, ch_reboot, l_volume, e_volume)
  f.add(b_next, b_cancel)
  answer = f.run
  if answer == b_next && ((r_udpsender.get == '*' && !File.exist?("/usr/sbin/udp-sender")) || (r_udpreciever.get == '*' && !File.exist?("/usr/sbin/udp-receiver")))
    Newt::Screen.win_message(_("Missing feature"), _("Try again"), _("UDP cast utility not available in this build"))
    pipeline.append :screen_image_mode
  elsif answer == b_next
    pipeline.append :screen_image_compress
    pipeline.data.volume = e_volume.get
    pipeline.data.reboot = (ch_reboot.get == '*')
    if r_http.get == '*'
      pipeline.append :screen_image_http
    else
      pipeline.data.udpcast = (r_udpsender.get == '*') ? "sender" : "reciever"
      pipeline.append :screen_image_udpcast
    end
  else
    pipeline.cancel
  end
end
