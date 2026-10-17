{ inputs, config, ... }:

let
  repoPath = "${config.home.homeDirectory}/nixos/home/desktop/noctalia";
  mkSymlink = config.lib.file.mkOutOfStoreSymlink;
in
{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia = {
    enable = true;
    settings = ./config.toml;
  };

  xdg.configFile = {
    "noctalia/templates/gtk-3.0.css".source = mkSymlink "${repoPath}/templates/gtk-3.0.css";
    "noctalia/templates/gtk-4.0.css".source = mkSymlink "${repoPath}/templates/gtk-4.0.css";
    "noctalia/templates/mango.conf".source = mkSymlink "${repoPath}/templates/mango.conf";
    "noctalia/templates/fcitx5".source = mkSymlink "${repoPath}/templates/fcitx5";
  };
}
