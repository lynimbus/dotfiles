{ pkgs, ... }:

{
  programs.ghostty = {
    enable = true;

    settings = {
      font-family = "Maple Mono NF CN";
      font-size = 13;

      background-opacity = 0.93;
      background-blur = true;

      window-decoration = "none";
      maximize = true;

      copy-on-select = "clipboard";
      command = "${pkgs.fish}/bin/fish --login";
    };
  };
}
