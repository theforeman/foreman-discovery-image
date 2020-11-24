def screen_foreman mac = nil, gw = nil, proxy_url = cmdline('proxy.url'), proxy_type = cmdline('proxy.type')
  Newt::Screen.centered_window(59, 20, _("Credentials"))
  f = Newt::Form.new
  t_desc = Newt::Textbox.new(2, 2, 54, 6, Newt::FLAG_WRAP)
  t_desc.set_text _("Provide full URL (http(s)://host:PORT) to the Server or Foreman Proxy according to the type selected. Ports are usually 443, 8443, 8448 or 9090 according to configuration.")
  l_url = Newt::Label.new(2, 8, _("Server URL:"))
  l_type = Newt::Label.new(2, 10, _("Connection type:"))
  t_url = Newt::Entry.new(20, 8, "", 36, Newt::FLAG_SCROLL)
  r_server = Newt::RadioButton.new(20, 10, _("Server"), 0, nil)
  r_proxy = Newt::RadioButton.new(32, 10, _("Foreman Proxy"), 1, r_server)
  b_ok = Newt::Button.new(34, 15, _("Next"))
  b_cancel = Newt::Button.new(46, 15, _("Cancel"))
  proxy_type ||= 'foreman'
  t_url.set(proxy_url, 1) if proxy_url
  r_server.set(proxy_type != 'proxy' ? '*' : ' ')
  r_proxy.set(proxy_type == 'proxy' ? '*' : ' ')
  items = [t_desc, l_type, l_url, t_url, r_server, r_proxy]
  if proxy_url
    f.add(b_ok, b_cancel, *items)
  else
    f.add(*items, b_ok, b_cancel)
  end
  answer = f.run
  if answer == b_ok
    begin
      proxy_type = r_server.get == '*' ? 'foreman' : 'proxy'
      url = t_url.get
      raise _("No URL was provided") if url.size < 1
      proxy_url = URI.parse(url)
      unless [443, 8443, 8448, 9090].include? proxy_url.port
        Newt::Screen.win_message(_("Warning"), _("OK"), _("Port %s is likely not correct, expected ports are 443, 8443 or 9090") % proxy_url.port)
      end
    rescue Exception => e
      Newt::Screen.win_message(_("Invalid URL"), _("OK"), _("Not a valid URL") + ": #{url} (#{e})")
      return [:screen_foreman, mac, gw, url, proxy_type]
    end
    [:screen_facts, mac, proxy_url, proxy_type]
  else
    :screen_welcome
  end
end
