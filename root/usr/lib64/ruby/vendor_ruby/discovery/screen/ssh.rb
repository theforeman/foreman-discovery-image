def screen_ssh
  t_desc = Newt::Textbox.new(-1, -1, 39, 3, Newt::FLAG_WRAP)
  t_desc.set_text _("Enter root password to unlock the account and enable SSH service:")
  e_password = Newt::Entry.new(-1, -1, "", 39, Newt::FLAG_PASSWORD)
  b_enable = Newt::Button.new(-1, -1, _("Set and Enable"))
  b_disable = Newt::Button.new(-1, -1, _("Disable"))
  b_cancel = Newt::Button.new(-1, -1, _("Cancel"))

  main_grid = Newt::Grid.new(1, 3)
  but_grid = Newt::Grid.new(3, 1)

  but_grid.set_field(0, 0, Newt::GRID_COMPONENT, b_enable, 0, 0, 0, 0, 0, 0)
  but_grid.set_field(1, 0, Newt::GRID_COMPONENT, b_disable, 0, 0, 0, 0, 0, 0)
  but_grid.set_field(2, 0, Newt::GRID_COMPONENT, b_cancel, 0, 0, 0, 0, 0, 0)

  main_grid.set_field(0, 0, Newt::GRID_COMPONENT, t_desc, 0, 0, 0, 0, 0, 0)
  main_grid.set_field(0, 1, Newt::GRID_COMPONENT, e_password, 0, 0, 0, 0, 0, 0)
  main_grid.set_field(0, 2, Newt::GRID_SUBGRID, but_grid, 0, 1, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.wrapped_window(_("Secure Shell access"))

  f = Newt::Form.new
  f.add(t_desc, e_password, b_enable, b_disable, b_cancel)
  answer = f.run()
  if answer == b_enable
    enable_root_account(e_password.get)
  elsif answer == b_disable
    command("systemctl stop sshd.service")
  elsif answer == b_cancel
    :screen_welcome
  end
  :screen_status
end
