def screen_info action_proc, message, error_message, success_screen, failure_screen
  text_help, tw, th = Newt.reflow_text(message, 60, 5, 5)
  t = Newt::Textbox.new(-1, -1, tw, th, Newt::FLAG_WRAP)
  t.set_text(text_help)

  main_grid = Newt::Grid.new(1, 1)
  main_grid.set_field(0, 0, Newt::GRID_COMPONENT, t, 0, 0, 0, 1, 0, 0)
  main_grid.wrapped_window("Waiting for operation to complete")

  f = Newt::Form.new
  f.add(t)
  f.draw
  Newt::Screen.refresh

  if action_proc.call
    success_screen
  else
    Newt::Screen.win_message("Operation failed", "OK", error_message)
    failure_screen
  end
end
