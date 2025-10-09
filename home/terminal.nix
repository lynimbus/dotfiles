{ ... }:
{
  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font Mono";
      size = 14;
    };
    themeFile = "GitHub_Dark";
    settings = {
      confirm_os_window_close = 0;
      remember_window_size = "no";
      initial_window_width = 800;
      initial_window_height = 600;
    };
  };
}
