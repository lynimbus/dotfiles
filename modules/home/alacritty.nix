{
  config,
  pkgs,
  ...
}: {
  programs.alacritty = {
    enable = true;
    settings = {
      font = {
        normal = {
          family = "Maple Mono NF CN";
          style = "Regular";
        };
        bold = {
          family = "Maple Mono NF CN";
          style = "Bold";
        };
        italic = {
          family = "Maple Mono NF CN";
          style = "Italic";
        };
        size = 12.0;
      };
    };
  };
}
