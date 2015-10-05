def generate_info extra_status = ''
  status = "N/A (use Status to update)"
  response = "N/A"
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
Status: #{status}

Primary NIC: #{get_mac}
Primary IPv4: #{get_ipv4}

Discovery server: #{discover_server || 'N/A'}
Endpoint type: #{proxy_type}

Latest server response:
#{response}

Kernel command line:
  #{cmdline.split(' ').join("\n  ")}
EOS
end

def screen_status status = generate_info, active_button = 0
  t_status = Newt::Textbox.new(-1, -1, 70, 16, Newt::FLAG_SCROLL)
  t_status.set_text(status)

  buttons = []
  buttons[0] = b_resend = Newt::CompactButton.new(-1, -1, "Resend")
  buttons[1] = b_status = Newt::CompactButton.new(-1, -1, "Status")
  buttons[2] = b_facts = Newt::CompactButton.new(-1, -1, "Facts")
  buttons[3] = b_network = Newt::CompactButton.new(-1, -1, "Network")
  buttons[4] = b_syslog = Newt::CompactButton.new(-1, -1, "System log")
  buttons[5] = b_ssh = Newt::CompactButton.new(-1, -1, "SSH")
  buttons[6] = b_reboot = Newt::CompactButton.new(-1, -1, "Reboot")

  main_grid = Newt::Grid.new(1, 2)
  but_grid = Newt::Grid.new(7, 1)

  buttons.each_with_index do |btn, i|
    but_grid.set_field(i, 0, Newt::GRID_COMPONENT, btn, 0, 0, 0, 0, 0, 0)
  end

  main_grid.set_field(0, 0, Newt::GRID_COMPONENT, t_status, 0, 0, 0, 0, 0, 0)
  main_grid.set_field(0, 1, Newt::GRID_SUBGRID, but_grid, 0, 1, 0, 0, 0, Newt::GRID_FLAG_GROWX)
  main_grid.wrapped_window("Discovery status")

  f = Newt::Form.new
  f.add(t_status, b_resend, b_status, b_facts, b_network, b_syslog, b_ssh, b_reboot)
  answer = f.run()
  if answer == b_status
    :screen_status
  elsif answer == b_facts
    [:screen_status, command("facter")]
  elsif answer == b_network
    [:screen_status, command("discovery-debug --tui")]
  elsif answer == b_syslog
    [:screen_status, command("journalctl -n300 -ocat")]
  elsif answer == b_reboot
    [:screen_status, command("shutdown -r now Reboot from TUI")]
  elsif answer == b_ssh
    :screen_ssh
  elsif answer == b_resend
    command("rm -f /tmp/discovery-http*")
    command("systemctl reload discovery-register")
    :screen_status
  else
    :quit
  end
end
