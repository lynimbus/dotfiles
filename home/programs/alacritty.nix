{ pkgs, ... }:

{
  programs.alacritty = {
    enable = true;

    settings = {
      window = {
        opacity = 0.93;
        startup_mode = "Maximized";
        dynamic_title = true;
        decorations = "None";
      };

      scrolling.history = 10000;

      font = {
        normal.family = "Maple Mono NF CN";
        bold.family = "Maple Mono NF CN";
        italic.family = "Maple Mono NF CN";
        bold_italic.family = "Maple Mono NF CN";
        size = 13;
      };

      terminal = {
        shell = {
          program = "${pkgs.fish}/bin/fish";
          args = [ "--login" ];
        };
        # zellij 之类的应用靠 OSC 52 写系统剪贴板
        osc52 = "CopyPaste";
      };
    };
  };
}
