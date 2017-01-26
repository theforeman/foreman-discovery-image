def screen_image_compress pipeline
  b_next = Newt::Button.new(-1, -1, _("Next"))
  b_cancel = Newt::Button.new(-1, -1, _("Cancel"))

  width = 50
  t_desc = Newt::Textbox.new(-1, -1, width, 4, Newt::FLAG_WRAP)
  t_desc.set_text _("Raw images may contain lots of nulls, it is good idea to compress them. Select (de)compressor to use.")

  top_grid = Newt::Grid.new(1, 3)
  form_grid = Newt::Grid.new(1, 5)
  but_grid = Newt::Grid.new(2, 1)

  # set_field(column, row, type, value, pad_left, pad_top, pad_right, pad_bottom, anchor, flags)
  but_grid.set_field(0, 0, Newt::GRID_COMPONENT, b_next, 1, 0, 1, 0, 0, 0)
  but_grid.set_field(1, 0, Newt::GRID_COMPONENT, b_cancel, 1, 0, 1, 0, 0, 0)

  r_none = Newt::RadioButton.new(-1, -1, _("No compression"), 1, nil)
  r_gzip = Newt::RadioButton.new(-1, -1, _("gzip"), 0, r_none)
  r_bz2 = Newt::RadioButton.new(-1, -1, _("bzip2"), 0, r_gzip)
  r_xz = Newt::RadioButton.new(-1, -1, _("xz"), 0, r_bz2)
  r_lzop = Newt::RadioButton.new(-1, -1, _("lzop"), 0, r_xz)

  form_grid.set_field(0, 0, Newt::GRID_COMPONENT, r_none, 0, 0, 1, 0, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(0, 1, Newt::GRID_COMPONENT, r_gzip, 0, 0, 0, 0, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(0, 2, Newt::GRID_COMPONENT, r_bz2, 0, 0, 0, 0, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(0, 3, Newt::GRID_COMPONENT, r_xz, 0, 0, 0, 0, Newt::ANCHOR_LEFT, 0)
  form_grid.set_field(0, 4, Newt::GRID_COMPONENT, r_lzop, 0, 0, 0, 1, Newt::ANCHOR_LEFT, 0)

  top_grid.set_field(0, 0, Newt::GRID_COMPONENT, t_desc, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  top_grid.set_field(0, 1, Newt::GRID_SUBGRID, form_grid, 0, 0, 0, 0, 0, 0)
  top_grid.set_field(0, 2, Newt::GRID_SUBGRID, but_grid, 0, 0, 0, 0, 0, 0)

  top_grid.wrapped_window(_("Image transfer - compression"))

  f = Newt::Form.new
  f.add(t_desc, r_none, r_gzip, r_bz2, r_xz, r_lzop)
  f.add(b_next, b_cancel)
  answer = f.run
  if answer == b_next
    compress_cmds = ["cat", "gzip -c", "bzip2 -c", "xz -c", "lzop -c"]
    uncompress_cmds = ["cat", "gzip -d", "bzip2 -d", "xz -d", "lzop -d"]
    [r_none, r_gzip, r_bz2, r_xz, r_lzop].each_with_index do |rb, i|
      pipeline.data.compress_cmd = compress_cmds[i] if rb.get == '*'
      pipeline.data.uncompress_cmd = uncompress_cmds[i] if rb.get == '*'
    end
  else
    pipeline.cancel :screen_image_mode
  end
end
