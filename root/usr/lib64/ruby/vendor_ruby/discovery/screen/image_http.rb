def screen_image_http pipeline
  b_start = Newt::Button.new(-1, -1, _("Start"))
  b_cancel = Newt::Button.new(-1, -1, _("Cancel"))

  width = 50
  t_desc = Newt::Textbox.new(-1, -1, width, 4, Newt::FLAG_WRAP)
  t_desc.set_text _("Provide URL of a RAW image. When using compression, make sure it's not in a tarball (e.g. raw.gz or img.bz2 instead of tar.gz).")

  top_grid = Newt::Grid.new(1, 3)
  form_grid = Newt::Grid.new(2, 1)
  but_grid = Newt::Grid.new(2, 1)

  # set_field(column, row, type, value, pad_left, pad_top, pad_right, pad_bottom, anchor, flags)
  but_grid.set_field(0, 0, Newt::GRID_COMPONENT, b_start, 1, 0, 1, 0, 0, 0)
  but_grid.set_field(1, 0, Newt::GRID_COMPONENT, b_cancel, 1, 0, 1, 0, 0, 0)

  l_url = Newt::Label.new(-1, -1, _("URL:"))
  e_url = Newt::Entry.new(-1, -1, "", 45, 0)
  form_grid.set_field(0, 0, Newt::GRID_COMPONENT, l_url, 0, 0, 2, 1, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(1, 0, Newt::GRID_COMPONENT, e_url, 0, 0, 2, 1, Newt::ANCHOR_LEFT, 0)

  top_grid.set_field(0, 0, Newt::GRID_COMPONENT, t_desc, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  top_grid.set_field(0, 1, Newt::GRID_SUBGRID, form_grid, 0, 0, 0, 0, 0, 0)
  top_grid.set_field(0, 2, Newt::GRID_SUBGRID, but_grid, 0, 0, 0, 0, 0, 0)

  top_grid.wrapped_window(_("Image transfer - http(s)"))

  f = Newt::Form.new
  f.add(t_desc)
  f.add(l_url, e_url)
  f.add(b_start, b_cancel)
  answer = f.run
  if answer == b_start
    cmd = "curl -k #{e_url.get} | #{pipeline.data.uncompress_cmd} > #{pipeline.data.volume}"
    action = Proc.new do
      begin
        command(cmd, true, true, false, false)
        result = ($? == 0)
        command("shutdown -r now 'Reboot after image transfer'") if pipeline.data.reboot
        result
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
