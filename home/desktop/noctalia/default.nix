{
  inputs,
  liveFiles,
  ...
}:

{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  programs.noctalia = {
    enable = true;
    settings = ./config.toml;
  };

  dconf.settings."org/gnome/desktop/interface" = {
    gtk-theme = "adw-gtk3";
  };

  xdg.configFile = liveFiles {
    from = "desktop/noctalia/templates";
    into = "noctalia/templates";
    files = [
      "umbriel-gtk"
      "fcitx5-mellow"
    ];
  };

  xdg.dataFile = liveFiles {
    from = "desktop/noctalia/plugins";
    into = "noctalia/plugins";
    files = [
      "m3-expressive"
    ];
  };
}
