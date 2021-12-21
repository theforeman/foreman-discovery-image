def screen_countdown discovery_only = false
  text_help, tw, th = Newt.reflow_text(_('This system will attempt to configure all interfaces via DHCP and discover itself by sending hardware facts to Foreman instance. To interrupt this behavior, press a key to be able to do manual network configuration and additional provisioning settings.'), 60, 5, 5)
  t = Newt::Textbox.new(-1, -1, tw, th, Newt::FLAG_WRAP)
  t.set_text(text_help)

  secs = cmdline("fdi.countdown", 45).to_i rescue 45
  l_press = Newt::Label.new(-1, -1, "< " + _('Press any key') + " (#{secs}s) >")

  main_grid = Newt::Grid.new(1, 2)
  but_grid = Newt::Grid.new(1, 1)

  but_grid.set_field(0, 0, Newt::GRID_COMPONENT, l_press, 0, 0, 0, 0, 0, 0)

  main_grid.set_field(0, 0, Newt::GRID_COMPONENT, t, 0, 0, 0, 1, 0, 0)
  main_grid.set_field(0, 1, Newt::GRID_SUBGRID, but_grid, 0, 0, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.wrapped_window(_("Welcome to Foreman Discovery"))

  f = Newt::Form.new
  f.add(t, l_press)
  f.draw
  key_was_pressed = false
  unless discovery_only
    sec = secs
    while sec > 0
      l_press.set_text("< " + _('Press any key') + " ... (#{sec}s) >")
      sec = sec - 1
      Newt::Screen.refresh
      if (STDIN.read_nonblock(1) rescue nil)
        key_was_pressed = true
        break
      end
      sleep 1
    end
  end

  if key_was_pressed
    :screen_welcome
  else
    start_discovery_service
    # additional countdown to let discovery-register do its work
    sec = secs
    while sec > 0
      l_press.set_text("< " + _('Discovery') + " ... (#{sec}s) >")
      sec = sec - 1
      Newt::Screen.refresh
      # break countdown on keypress or IPC
      break if (STDIN.read_nonblock(1) rescue nil)
      break if File.exist?("/tmp/discovery-http-success")
      break if File.exist?("/tmp/discovery-http-failure")
      sleep 1
    end
    :screen_status
  end
end
