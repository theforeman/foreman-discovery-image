def screen_facts mac, proxy_url, proxy_type
  custom_facts = new_custom_facts(mac)

  b_confirm = Newt::Button.new(-1, -1, _("Confirm"))
  b_cancel = Newt::Button.new(-1, -1, _("Cancel"))

  top_grid = Newt::Grid.new(1, 2)
  facts_grid = Newt::Grid.new(4, 9)
  but_grid = Newt::Grid.new(2, 1)

  but_grid.set_field(0, 0, Newt::GRID_COMPONENT, b_confirm, 0, 0, 2, 0, 0, 0)
  but_grid.set_field(1, 0, Newt::GRID_COMPONENT, b_cancel, 0, 0, 2, 0, 0, 0)

  names = []; values = []; labels = []; labels_sep = []
  (0..8).each_with_index do |ix, _|
    labels[ix] = Newt::Label.new(-1, -1, (_("Fact %s name") % ('#' + (ix + 1).to_s)) + ' ')
    labels_sep[ix] = Newt::Label.new(-1, -1, ' ' + _('value') + ' ')
    names[ix] = Newt::Entry.new(-1, -1, cmdline("fdi.pxfactname#{ix + 1}").to_s, 15, Newt::FLAG_SCROLL)
    values[ix] = Newt::Entry.new(-1, -1, cmdline("fdi.pxfactvalue#{ix + 1}").to_s, 15, Newt::FLAG_SCROLL)
    facts_grid.set_field(0, ix, Newt::GRID_COMPONENT, labels[ix], 0, 0, 0, 0, 0, 0)
    facts_grid.set_field(1, ix, Newt::GRID_COMPONENT, names[ix], 0, 0, 0, 0, 0, 0)
    facts_grid.set_field(2, ix, Newt::GRID_COMPONENT, labels_sep[ix], 0, 0, 0, 0, 0, 0)
    facts_grid.set_field(3, ix, Newt::GRID_COMPONENT, values[ix], 0, 0, 0, 0, 0, 0)
  end

  top_grid.set_field(0, 0, Newt::GRID_SUBGRID, facts_grid, 0, 0, 0, 0, 0, 0)
  top_grid.set_field(0, 1, Newt::GRID_SUBGRID, but_grid, 0, 2, 0, 0, 0, 0)

  top_grid.wrapped_window(_("Custom facts"))

  f = Newt::Form.new
  f.add(b_confirm, b_cancel)
  (0..8).each_with_index do |ix, _|
    f.add(labels[ix], names[ix], labels_sep[ix], values[ix])
  end
  answer = f.run
  if answer == b_confirm
    (0..8).each_with_index do |ix, _|
      custom_facts[names[ix].get] = values[ix].get if names[ix].get && values[ix].get
    end
    if perform_upload(proxy_url, proxy_type, custom_facts)
      [:screen_status, generate_info(' - ' + _('awaiting kexec into installer'))]
    else
      [:screen_status, generate_info(' - ' + _('fact upload failed'))]
    end
  else
    :screen_welcome
  end
end
