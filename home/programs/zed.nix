{ ... }:

{
  programs.zed-editor = {
    enable = true;
    userSettings = {
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      vim_mode = true;
      ui_font_size = 16;
      buffer_font_size = 16;
      buffer_font_family = "Intel One Mono";
      buffer_font_fallbacks = [
        "Maple Mono NF CN"
        "Noto Sans CJK SC"
      ];
      theme = {
        mode = "dark";
        light = "One Light";
        dark = "One Dark";
      };
      remove_trailing_whitespace_on_save = false;
      ensure_final_newline_on_save = true;
    };
  };
}
