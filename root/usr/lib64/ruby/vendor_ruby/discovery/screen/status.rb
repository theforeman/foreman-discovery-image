def generate_info extra_status = '', server = nil, type = nil
  return "N/A" if ENV['FDI_DEVEL']
  server ||= discover_server
  type ||= proxy_type
  status = _("N/A") + ' (' + _("use Status to update") + ')'
  response = _("N/A")
  if File.exist?(f = '/tmp/discovery-http-success')
    status = "SUCCESS #{extra_status}"
    response = wrap(IO.read(f), 65)
  elsif File.exist?(f = '/tmp/discovery-http-failure')
    status = "FAILURE #{extra_status}"
    response = wrap(IO.read(f), 65)
  elsif extra_status != ''
    status = extra_status
    response = ''
  end
  <<EOS
#{_('Status')}: #{status}

#{_('Primary NIC')}: #{get_mac}
#{_('Primary IPv4')}: #{get_ipv4}

#{_('Discovery server')}: #{discover_server || 'N/A'}
#{_('Endpoint type')}: #{type}

#{_('Latest server response')}:
#{response}

#{_('Kernel command line')}:
  #{cmdline.split(' ').join("\n  ")}
EOS
end

def screen_status pipeline
  t_status = Newt::Textbox.new(-1, -1, 70, 16, Newt::FLAG_SCROLL)
  t_status.set_text(pipeline.data.status_text || generate_info)

  buttons = []
  buttons[0] = b_resend = Newt::CompactButton.new(-1, -1, _("Resend"))
  buttons[1] = b_status = Newt::CompactButton.new(-1, -1, _("Status"))
  buttons[2] = b_facts = Newt::CompactButton.new(-1, -1, _("Facts"))
  buttons[3] = b_image = Newt::CompactButton.new(-1, -1, _("Image"))
  buttons[4] = b_syslog = Newt::CompactButton.new(-1, -1, _("Logs"))
  buttons[5] = b_ssh = Newt::CompactButton.new(-1, -1, _("SSH"))
  buttons[6] = b_reboot = Newt::CompactButton.new(-1, -1, _("Reboot"))

  main_grid = Newt::Grid.new(1, 2)
  but_grid = Newt::Grid.new(7, 1)

  buttons.each_with_index do |btn, i|
    but_grid.set_field(i, 0, Newt::GRID_COMPONENT, btn, 0, 0, 0, 0, 0, 0)
  end

  main_grid.set_field(0, 0, Newt::GRID_COMPONENT, t_status, 0, 0, 0, 0, 0, 0)
  main_grid.set_field(0, 1, Newt::GRID_SUBGRID, but_grid, 0, 1, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.wrapped_window(_("Discovery status"))

  f = Newt::Form.new
  f.add(t_status, b_resend, b_status, b_facts, b_image, b_syslog, b_ssh, b_reboot)
  answer = f.run()
  if answer == b_status
    :screen_status
  elsif answer == b_facts
    [:screen_status, command("facter")]
  elsif answer == b_syslog
    [:screen_status, command("discovery-debug")]
  elsif answer == b_reboot
    [:screen_status, command("shutdown -r now Reboot from TUI")]
  elsif answer == b_ssh
    :screen_ssh
  elsif answer == b_image
    [:screen_primary_iface, false, :screen_image, :screen_status, _("Transfer interface"), message = _("Select interface for udpcast image transfer:")]
  elsif answer == b_resend
    if cmdline('BOOTIF')
      command("rm -f /tmp/discovery-http*")
      # discovery register will be restarted in countdown screen
      [:screen_countdown, true]
    else
      Newt::Screen.win_message(_("Not supported"), _("OK"), _("Resending not possible in PXE-less, reboot and start over."))
      :screen_status
    end
  else
    :quit
  end
end
