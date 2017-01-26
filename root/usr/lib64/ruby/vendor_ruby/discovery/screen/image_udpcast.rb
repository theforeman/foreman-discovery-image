def screen_image_udpcast pipeline
  b_start = Newt::Button.new(-1, -1, _("Start"))
  b_cancel = Newt::Button.new(-1, -1, _("Cancel"))

  width = 50
  t_desc = Newt::Textbox.new(-1, -1, width, 4, Newt::FLAG_WRAP)
  t_desc.set_text _("Use port range 9000-9100 or change firewall configuration. Switch to console 2 (ALT+F2) or use journalctl to watch progress.")

  top_grid = Newt::Grid.new(1, 3)
  form_grid = Newt::Grid.new(2, 2)
  but_grid = Newt::Grid.new(2, 1)

  # set_field(column, row, type, value, pad_left, pad_top, pad_right, pad_bottom, anchor, flags)
  but_grid.set_field(0, 0, Newt::GRID_COMPONENT, b_start, 1, 0, 1, 0, 0, 0)
  but_grid.set_field(1, 0, Newt::GRID_COMPONENT, b_cancel, 1, 0, 1, 0, 0, 0)

  l_port = Newt::Label.new(-1, -1, _("Port (N, N+1):"))
  e_port = Newt::Entry.new(-1, -1, "9000", 10, 0)
  l_extra = Newt::Label.new(-1, -1, _("Extra options:"))
  e_extra = Newt::Entry.new(-1, -1, "", 30, Newt::FLAG_SCROLL)
  form_grid.set_field(0, 0, Newt::GRID_COMPONENT, l_port, 0, 0, 2, 1, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(1, 0, Newt::GRID_COMPONENT, e_port, 0, 0, 2, 1, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(0, 1, Newt::GRID_COMPONENT, l_extra, 0, 0, 2, 1, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(1, 1, Newt::GRID_COMPONENT, e_extra, 0, 0, 2, 1, Newt::ANCHOR_LEFT, 0)

  top_grid.set_field(0, 0, Newt::GRID_COMPONENT, t_desc, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  top_grid.set_field(0, 1, Newt::GRID_SUBGRID, form_grid, 0, 0, 0, 0, 0, 0)
  top_grid.set_field(0, 2, Newt::GRID_SUBGRID, but_grid, 0, 0, 0, 0, 0, 0)

  top_grid.wrapped_window(_("Image transfer - udpcast"))

  f = Newt::Form.new
  f.add(t_desc)
  f.add(l_port, e_port)
  f.add(l_extra, e_extra)
  f.add(b_start, b_cancel)
  answer = f.run
  if answer == b_start
    log_file = "/tmp/udpcast.log"
    File.delete(log_file) if File.exists?(log_file)
    if pipeline.data.udpcast == "receiver"
      cmd = "udp-receiver --interface #{pipeline.data.primary_name} --portbase #{e_port.get} --nokbd #{e_extra.get} --log #{log_file} | #{pipeline.data.uncompress_cmd} > #{pipeline.data.volume}"
    else
      cmd = "cat #{pipeline.data.volume} | #{pipeline.data.compress_cmd} | udp-sender --interface #{pipeline.data.primary_name} --portbase #{e_port.get} --nokbd #{e_extra.get} --log #{log_file}"
    end
    action = Proc.new do
      begin
        command(cmd, true, true, false, false)
        result = ($? == 0)
        command("shutdown -r now 'Reboot after image transfer'") if pipeline.data.reboot
        result
      ensure
        command("systemd-cat -t udpcast < #{log_file}", false, false, false, false) if File.exists?(log_file)
      end
    end
    pipeline.append :screen_info
    pipeline.append :screen_welcome
    pipeline.data.action_proc = action
    pipeline.data.message = _("Work in progress, use tty2 for more details...")
    pipeline.data.error_message = _("Unable to transfer image, investigate logs.")
  else
    pipeline.cancel :screen_image_mode
  end
end
