{ ... }:
{
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font Mono";
      size = 14;
    };
    themeFile = "Dracula";
    settings = {
      window_border_width = "0px";
      tab_bar_edge = "top";
      tab_bar_margin_width = "0.0";
      tab_bar_style = "fade";
      placement_strategy = "top-left";
      confirm_os_window_close = 0;
      remember_window_size = "no";
      initial_window_width = 800;
      initial_window_height = 600;
    };
  };
}
