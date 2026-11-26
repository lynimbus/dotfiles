{
  config,
  inputs,
  lib,
  liveFiles,
  pkgs,
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

  # Runtime tools for the official noctalia/mpvpaper video wallpaper plugin
  # (mpvpaper renders the background layer; socat tracks slideshow state over
  # mpv JSON IPC so extracted static frames and M3 theme colors stay in sync).
  home.packages = with pkgs; [
    mpvpaper
    socat
  ];

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

  xdg.dataFile =
    liveFiles {
      from = "desktop/noctalia/plugins";
      into = "noctalia/plugins";
      files = [
        "m3-expressive"
      ];
    }
    // {
      "noctalia/wallpapers".source = ./wallpapers;
    };

  # Seed writable mpvpaper plugin state on first activation so dynamic video
  # wallpapers and 10-minute slideshow rotation start automatically without
  # overriding manual selections made later in the picker.
  home.activation.seedMpvpaperState = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    state_dir="${config.xdg.stateHome}/noctalia/mpvpaper"
    cache_dir="${config.xdg.cacheHome}/noctalia/mpvpaper"
    assignments_file="$state_dir/assignments.json"
    slideshow_file="$state_dir/slideshow_override.json"
    default_video="${config.xdg.dataHome}/noctalia/wallpapers/Claude.mp4"

    mkdir -p "$state_dir" "$cache_dir"
    if [ ! -s "$assignments_file" ]; then
      printf '{"assignments":{"*":"%s"}}\n' "$default_video" > "$assignments_file"
    fi
    if [ ! -s "$slideshow_file" ]; then
      printf '{"interval":600}\n' > "$slideshow_file"
    fi
  '';
}
