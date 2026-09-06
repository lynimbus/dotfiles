{
  config,
  inputs,
  lib,
  pkgs,
  username,
  email,
  ...
}:

{
  imports = [
    inputs.deepseek-harness.homeModules.default
    inputs.niri-flake.homeModules.config
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    ripgrep
    fzf
    jq
    just
    nvd
    gh
    jjui
    ungoogled-chromium
    ayugram-desktop
    qq
    wechat-uos

    delta
    mergiraf

    fd
    eza
    bat
    fastfetch
    zoxide
    dig
    android-tools
    shellcheck
    libxml2
    file

    zigpkgs.master
    koka

    zip
    unzip
    p7zip
    xz
    ffmpeg
    imagemagick
    poppler

    ladspaPlugins
    rnnoise-plugin

    brightnessctl
    ddcutil
    wlsunset
    tmux
    fish
    libnotify
    gvfs
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications."inode/directory" = [ "org.kde.dolphin.desktop" ];
  };

  programs.ghostty = {
    enable = true;
    settings = {
      theme = "Atom One Dark";
      window-padding-x = 8;
      window-padding-y = 8;
      cursor-style = "block";
      font-family = "JetBrainsMono Nerd Font Mono";
      font-size = 12;
    };
  };

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
      theme = {
        mode = "dark";
        light = "One Light";
        dark = "One Dark";
      };
      remove_trailing_whitespace_on_save = false;
      ensure_final_newline_on_save = true;
    };
  };

  programs.yazi = {
    enable = true;
    enableNushellIntegration = true;

    plugins = with pkgs.yaziPlugins; {
      inherit
        nord
        yatline
        full-border
        smart-enter
        ouch
        jump-to-char
        bypass
        ;
    };

    flavors = { inherit (pkgs.yaziPlugins) nord; };

    theme.flavor = {
      light = "nord";
      dark = "nord";
    };

    initLua = ''
      require("yatline"):setup({
        theme = require("nord"):setup(),
      })
      require("full-border"):setup()
    '';

    keymap = {
      mgr.prepend_keymap = [
        {
          on = [ "h" ];
          run = "plugin bypass reverse";
        }
        {
          on = [ "<Left>" ];
          run = "plugin bypass reverse";
        }
        {
          on = [ "l" ];
          run = "plugin bypass smart-enter";
        }
        {
          on = [ "<Enter>" ];
          run = "plugin bypass smart-enter";
        }
        {
          on = [ "<Right>" ];
          run = "plugin bypass smart-enter";
        }
        {
          on = [ "C" ];
          run = "plugin ouch";
        }
        {
          on = [ "f" ];
          run = "plugin jump-to-char";
        }
      ];
    };
    settings = {
      plugin = {
        prepend_previewers = [
          {
            mime = "application/*zip";
            run = "ouch";
          }
          {
            mime = "application/x-tar";
            run = "ouch";
          }
          {
            mime = "application/x-bzip2";
            run = "ouch";
          }
          {
            mime = "application/x-7z-compressed";
            run = "ouch";
          }
          {
            mime = "application/x-rar";
            run = "ouch";
          }
          {
            mime = "application/vnd.rar";
            run = "ouch";
          }
          {
            mime = "application/x-xz";
            run = "ouch";
          }
          {
            mime = "application/xz";
            run = "ouch";
          }
          {
            mime = "application/x-zstd";
            run = "ouch";
          }
          {
            mime = "application/zstd";
            run = "ouch";
          }
          {
            mime = "application/java-archive";
            run = "ouch";
          }
        ];
      };
    };
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user.name = username;
      user.email = email;
      git = {
        sign-on-push = true;
        private-commits = "description(glob:'wip:*') | description(glob:'private:*')";
      };
      ui = {
        default-command = "log";
        editor = "nvim";
        pager = "delta";
        merge-editor = "mergiraf";
      };
      revset-aliases = {
        "immutable_heads()" = "untracked_remote_bookmarks()";
      };
      signing = {
        backend = "ssh";
        key = "/home/${username}/.ssh/id_ed25519";
      };
    };
  };

  programs.git = {
    enable = true;
    settings = {
      user.name = username;
      user.email = email;
      init.defaultBranch = "main";
      pull.rebase = true;

      core.pager = "delta";
      interactive.diffFilter = "delta --color-only";
      delta = {
        navigate = true;
        line-numbers = true;
        dark = true;
      };

      merge.conflictstyle = "zdiff3";
      diff.colorMoved = "default";
      push.autoSetupRemote = true;
      fetch.prune = true;
      rerere.enabled = true;
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        forwardAgent = true;
      };
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
  };

  xdg.configFile."pipewire/pipewire.conf.d/99-rnnoise.conf".text = ''
    context.modules = [
      {
        name = libpipewire-module-filter-chain
        args = {
          node.description = "Auto Gain + Noise Cancel Source"
          media.name = "Auto Gain + Noise Cancel Source"

          filter.graph = {
            nodes = [
              {
                type = ladspa
                name = gain_control
                plugin = "${pkgs.ladspaPlugins}/lib/ladspa/dyson_compress_1403.so"
                label = dysonCompress
                control = {
                  "Input Gain" = 2.0
                  "Threshold" = -18.0
                  "Ratio" = 3.0
                  "Attack Time" = 0.02
                  "Release Time" = 0.2
                  "Makeup Gain" = 3.0
                }
              }
              {
                type = ladspa
                name = rnnoise
                plugin = "${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so"
                label = noise_suppressor_mono
                control = {
                  "VAD Threshold (%)" = 80.0
                  "VAD Grace Period (ms)" = 200
                  "Retroactive VAD Grace (ms)" = 0
                }
              }
            ]
          }

          capture.props = {
            node.name = capture.rnnoise_source
            node.passive = true
            audio.rate = 48000
          }

          playback.props = {
            node.name = rnnoise_source
            media.class = Audio/Source
            audio.rate = 48000
          }
        }
      }
    ]
  '';

  programs.niri.settings = {
    includes = [
      {
        path = "effects.kdl";
        optional = true;
      }
    ];

    outputs = {
      "eDP-1" = {
        mode = {
          width = 2560;
          height = 1600;
          refresh = 240.0;
        };
        scale = 1.75;
        position = {
          x = 0;
          y = 0;
        };
      };
      "eDP-2" = {
        mode = {
          width = 2560;
          height = 1600;
          refresh = 240.0;
        };
        scale = 1.75;
        position = {
          x = 0;
          y = 0;
        };
      };
    };

    overview = {
      backdrop-color = "#4c566a90";
      workspace-shadow.enable = false;
    };

    environment = {
      XDG_CURRENT_DESKTOP = "niri";
      XDG_SESSION_TYPE = "wayland";
      GTK_IM_MODULE = "fcitx";
      ELECTRON_OZONE_PLATFORM_HINT = "auto";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_QPA_PLATFORMTHEME = "gtk3";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      NIXOS_OZONE_WL = "1";
    };

    spawn-at-startup = [
      { argv = [ "noctalia" ]; }
      {
        argv = [
          "~/.config/niri/toggle-eyecare.sh"
          "--sync"
        ];
      }
      {
        argv = [
          "fcitx5"
          "-d"
        ];
      }
      { sh = "sleep 8; noctalia msg config-reload && noctalia msg templates-apply"; }
    ];

    "hotkey-overlay"."skip-at-startup" = true;
    "prefer-no-csd" = true;
    "screenshot-path" = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

    debug = {
      "honor-xdg-activation-with-invalid-serial" = true;
    };

    recent-windows = {
      enable = true;
      binds = {
        "Alt+Tab".action."next-window".scope = "output";
        "Alt+Shift+Tab".action."previous-window".scope = "output";
        "Alt+grave".action."next-window".filter = "app-id";
        "Alt+Shift+grave".action."previous-window".filter = "app-id";
      };
      highlight = {
        "corner-radius" = 12;
        "active-color" = "#b6c7e7";
        "urgent-color" = "#ffb4ab";
      };
    };

    cursor = {
      theme = "Adwaita";
      size = 24;
    };

    gestures."hot-corners".enable = false;
    input = {
      keyboard.numlock = true;
      touchpad = {
        tap = true;
        "natural-scroll" = true;
        dwt = true;
        dwtp = true;
        "disabled-on-external-mouse" = true;
      };
      mouse."accel-speed" = -0.72;
    };

    layout = {
      "background-color" = "transparent";
      gaps = 12;
      "center-focused-column" = "never";
      "always-center-single-column" = true;
      "preset-column-widths" = [
        { proportion = 0.33333; }
        { proportion = 0.5; }
        { proportion = 0.66667; }
      ];
      "default-column-width" = {
        proportion = 0.5;
      };
      "focus-ring" = {
        enable = false;
      };
      shadow = {
        enable = true;
        softness = 10;
        spread = 4;
        offset = {
          x = 0;
          y = 0;
        };
        color = "#00000070";
      };
      "tab-indicator" = {
        active.color = "#b6c7e7";
        inactive.color = "#374761";
        urgent.color = "#ffb4ab";
      };
      "insert-hint" = {
        enable = true;
        display.color = "#b6c7e780";
      };
    };

    animations = {
      "workspace-switch" = {
        enable = true;
        kind.spring = {
          "damping-ratio" = 0.8;
          stiffness = 523;
          epsilon = 0.0001;
        };
      };
      "window-open" = {
        enable = true;
        kind.easing = {
          "duration-ms" = 150;
          curve = "ease-out-expo";
        };
      };
      "window-close" = {
        enable = true;
        kind.easing = {
          "duration-ms" = 150;
          curve = "ease-out-quad";
        };
      };
      "horizontal-view-movement" = {
        enable = true;
        kind.spring = {
          "damping-ratio" = 0.85;
          stiffness = 423;
          epsilon = 0.0001;
        };
      };
      "window-movement" = {
        enable = true;
        kind.spring = {
          "damping-ratio" = 0.75;
          stiffness = 323;
          epsilon = 0.0001;
        };
      };
      "window-resize" = {
        enable = true;
        kind.spring = {
          "damping-ratio" = 0.85;
          stiffness = 423;
          epsilon = 0.0001;
        };
      };
      "config-notification-open-close" = {
        enable = true;
        kind.spring = {
          "damping-ratio" = 0.65;
          stiffness = 923;
          epsilon = 0.001;
        };
      };
      "screenshot-ui-open" = {
        enable = true;
        kind.easing = {
          "duration-ms" = 200;
          curve = "ease-out-quad";
        };
      };
      "overview-open-close" = {
        enable = true;
        kind.spring = {
          "damping-ratio" = 0.85;
          stiffness = 800;
          epsilon = 0.0001;
        };
      };
    };

    blur = {
      enable = true;
      offset = 2.3;
      noise = 0.001;
      saturation = 2;
    };

    "layer-rules" = [
      {
        matches = [ { namespace = "^noctalia-wallpaper*"; } ];
        "place-within-backdrop" = true;
      }
      {
        matches = [ { namespace = "^mpvpaper$"; } ];
        "place-within-backdrop" = true;
      }
      {
        matches = [ { namespace = "^(noctalia-bar-bar|noctalia-bar-default)$"; } ];
        opacity = 1.0;
        "geometry-corner-radius" = {
          top-left = 0.0;
          top-right = 0.0;
          bottom-right = 0.0;
          bottom-left = 0.0;
        };
        shadow.enable = false;
        "background-effect".blur = false;
      }
    ];

    "window-rules" = [
      {
        "geometry-corner-radius" = {
          top-left = 12.0;
          top-right = 12.0;
          bottom-right = 12.0;
          bottom-left = 12.0;
        };
        "clip-to-geometry" = true;
        "draw-border-with-background" = false;
      }
      {
        matches = [ { "app-id" = "com.ghostty.float"; } ];
        "open-floating" = true;
      }
      {
        matches = [ { "app-id" = "dev.noctalia.Noctalia"; } ];
        "open-floating" = true;
      }
      {
        matches = [
          { "app-id" = "^gnome-control-center$"; }
          { "app-id" = "^pavucontrol$"; }
          { "app-id" = "^nm-connection-editor$"; }
        ];
        "default-column-width" = {
          proportion = 0.5;
        };
        "open-floating" = false;
      }
      {
        matches = [
          { "app-id" = "^org\\.gnome\\.Calculator$"; }
          { "app-id" = "^gnome-calculator$"; }
          { "app-id" = "^galculator$"; }
          { "app-id" = "^blueman-manager$"; }
          { "app-id" = "^org\\.gnome\\.Nautilus$"; }
          { "app-id" = "^xdg-desktop-portal$"; }
        ];
        "open-floating" = true;
        "draw-border-with-background" = false;
      }
      {
        matches = [ { "app-id" = "^org\\.gnome\\.Nautilus$"; } ];
        "draw-border-with-background" = false;
      }
      {
        matches = [ { "app-id" = "app.zen_browser.zen"; } ];
        "draw-border-with-background" = false;
      }
      {
        matches = [
          {
            "app-id" = "^steam$";
            title = "^notificationtoasts_\\d+_desktop$";
          }
        ];
        "default-floating-position" = {
          x = 10;
          y = 10;
          relative-to = "bottom-right";
        };
        "open-focused" = false;
      }
      {
        matches = [ { "app-id" = "zoom"; } ];
        "open-floating" = true;
      }
      {
        matches = [ { "app-id" = "wine"; } ];
        "open-floating" = true;
        "default-column-width" = {
          proportion = 1.0;
        };
        "draw-border-with-background" = false;
        opacity = 1.0;
        "background-effect".blur = false;
      }
      {
        matches = [
          {
            "app-id" = "(?i)^explorer\\.exe$";
            title = "^$";
          }
          {
            "app-id" = "(?i)^explorer\\.exe$";
            title = "(?i)^Wine System Tray$";
          }
          {
            "app-id" = "(?i)^explorer\\.exe$";
            title = "^Wine$";
          }
          { "app-id" = "(?i)^(wineboot|services)\\.exe$"; }
          { title = "(?i)^Wine System Tray$"; }
        ];
        "open-floating" = true;
        "open-focused" = false;
        opacity = 0.0;
        "default-floating-position" = {
          x = -9999;
          y = -9999;
          relative-to = "top-left";
        };
        shadow.enable = false;
      }
      {
        matches = [ { "app-id" = "^(chromium|chromium-browser|org\\.chromium\\.\\w+)$"; } ];
        opacity = 1.0;
        "background-effect".blur = false;
      }
      {
        matches = [
          { "app-id" = "^steam_app_.*"; }
          { "app-id" = "^gamescope$"; }
          { title = "(?i)genshin impact|zenless zone zero|victoria 3|Minecraft|Endfield"; }
        ];
        opacity = 1.0;
        "background-effect".blur = false;
        "draw-border-with-background" = false;
      }
      {
        matches = [ { title = "(画中画|Picture-in-Picture)"; } ];
        "open-floating" = true;
        opacity = 1.0;
        "default-column-width" = { };
        "default-window-height" = { };
        "default-floating-position" = {
          x = 20;
          y = 20;
          relative-to = "bottom-right";
        };
      }
      {
        matches = [
          { "app-id" = "org.kde.kdenlive"; }
          { "app-id" = "mpv"; }
          { "app-id" = "kazumi"; }
          { "app-id" = "celluloid"; }
          { "app-id" = "virt-manager"; }
        ];
        opacity = 1.0;
      }
      {
        matches = [
          { title = "(图片查看器|Image Viewer|图片和视频|Image and Video Viewer|视频播放器|Video Player|Videos)"; }
          { "app-id" = "org.gnome.Loupe"; }
          { "app-id" = "org.gnome.Totem"; }
          { "app-id" = "org.gnome.Photos"; }
        ];
        "open-floating" = true;
        opacity = 1.0;
      }
      {
        matches = [
          {
            "app-id" = "steam";
            title = "Friends List";
          }
          {
            "app-id" = "steam";
            title = "好友列表";
          }
        ];
        "default-column-width" = {
          proportion = 0.20;
        };
      }
      {
        matches = [
          {
            "app-id" = "QQ";
            title = "资料卡";
          }
          {
            "app-id" = "QQ";
            title = "天气";
          }
        ];
        "open-focused" = false;
      }
      {
        matches = [
          {
            "app-id" = "QQ";
            title = "群聊的聊天记录";
          }
        ];
        "open-floating" = true;
      }
      {
        matches = [ { "app-id" = "^wechat$"; } ];
        opacity = 1.0;
        "background-effect".blur = false;
      }
      {
        matches = [
          {
            "app-id" = "^wechat$";
            title = "(图片查看|选择一个聊天|转发|搜索)";
          }
        ];
        "open-floating" = true;
      }
      {
        matches = [ { "app-id" = "imv"; } ];
        "open-floating" = true;
      }
      {
        matches = [ { "app-id" = "io.ente.auth"; } ];
        "open-floating" = true;
        "default-column-width" = {
          fixed = 532;
        };
        "default-window-height" = {
          fixed = 925;
        };
      }
      {
        matches = [ { title = "(?i)scratchpad"; } ];
        "open-floating" = true;
        "default-floating-position" = {
          x = 0;
          y = 40;
          relative-to = "top";
        };
        "default-column-width" = {
          proportion = 0.5;
        };
        "default-window-height" = {
          proportion = 0.45;
        };
      }
    ];

    binds = {
      "Mod+Tab" = {
        repeat = false;
        action."toggle-overview" = [ ];
      };
      "Mod+Q".action."close-window" = [ ];
      "Mod+Shift+E".action.quit = [ ];
      "Mod+Shift+R".action.spawn = [
        "niri"
        "msg"
        "action"
        "load-config-file"
      ];
      "Mod+L".action.spawn = [
        "noctalia"
        "msg"
        "session"
        "lock"
      ];
      "Mod+Shift+L" = {
        "hotkey-overlay" = {
          title = "阻止待机/锁屏 (Caffeine)";
        };
        action.spawn = [
          "noctalia"
          "msg"
          "caffeine-toggle"
        ];
      };
      "Mod+Slash".action."show-hotkey-overlay" = [ ];

      "Mod+Return".action.spawn = [ "ghostty" ];
      "Mod+Shift+Return".action.spawn = [
        "ghostty"
        "--class=com.ghostty.float"
      ];
      "Mod+E".action.spawn = [ "dolphin" ];
      "Mod+B".action.spawn = [ "chromium" ];
      "Mod+R".action.spawn = [
        "noctalia"
        "msg"
        "panel-toggle"
        "launcher"
      ];
      "Mod+X".action.spawn = [
        "noctalia"
        "msg"
        "panel-toggle"
        "session"
      ];
      "Mod+I".action.spawn = [
        "noctalia"
        "msg"
        "settings-toggle"
      ];
      "Mod+V".action.spawn = [
        "noctalia"
        "msg"
        "panel-toggle"
        "clipboard"
      ];
      "Mod+W".action.spawn = [
        "noctalia"
        "msg"
        "panel-toggle"
        "wallpaper"
      ];
      "Mod+Ctrl+W".action.spawn = [
        "noctalia"
        "msg"
        "wallpaper-random"
      ];
      "Mod+N".action.spawn = [ "~/.config/niri/toggle-eyecare.sh" ];
      "Mod+Grave".action.spawn = [ "~/.config/niri/niri-scratch-toggle.sh" ];

      "Mod+Left".action."focus-column-or-monitor-left" = [ ];
      "Mod+Right".action."focus-column-or-monitor-right" = [ ];
      "Mod+Down".action."focus-window-or-workspace-down" = [ ];
      "Mod+Up".action."focus-window-or-workspace-up" = [ ];
      "Mod+Z".action."focus-column-left" = [ ];
      "Mod+C".action."focus-column-right" = [ ];
      "Mod+J".action."focus-window-down" = [ ];
      "Mod+K".action."focus-window-up" = [ ];
      "Mod+Ctrl+Left".action."move-column-left-or-to-monitor-left" = [ ];
      "Mod+Ctrl+Right".action."move-column-right-or-to-monitor-right" = [ ];
      "Mod+Ctrl+Down".action."move-window-down-or-to-workspace-down" = [ ];
      "Mod+Ctrl+Up".action."move-window-up-or-to-workspace-up" = [ ];
      "Mod+Shift+Left".action."move-column-left" = [ ];
      "Mod+Shift+Right".action."move-column-right" = [ ];
      "Mod+D".action."focus-workspace-down" = [ ];
      "Mod+U".action."focus-workspace-up" = [ ];
      "Mod+Shift+Ctrl+Left".action."move-column-to-monitor-left" = [ ];
      "Mod+Shift+Ctrl+Right".action."move-column-to-monitor-right" = [ ];
      "Mod+Shift+Ctrl+Down".action."move-column-to-monitor-down" = [ ];
      "Mod+Shift+Ctrl+Up".action."move-column-to-monitor-up" = [ ];

      "Mod+T".action."toggle-window-floating" = [ ];
      "Mod+Shift+T".action."switch-focus-between-floating-and-tiling" = [ ];
      "Mod+G".action."toggle-column-tabbed-display" = [ ];
      "Mod+F".action."maximize-column" = [ ];
      "Mod+Shift+F".action."fullscreen-window" = [ ];
      "Mod+Space".action."switch-preset-column-width" = [ ];
      "Mod+Minus".action."set-column-width" = [ "-5%" ];
      "Mod+Equal".action."set-column-width" = [ "+5%" ];
      "Mod+Shift+Equal".action."reset-window-height" = [ ];
      "Mod+Comma".action."consume-window-into-column" = [ ];
      "Mod+Period".action."expel-window-from-column" = [ ];

      "Mod+1".action."focus-workspace" = 1;
      "Mod+2".action."focus-workspace" = 2;
      "Mod+3".action."focus-workspace" = 3;
      "Mod+4".action."focus-workspace" = 4;
      "Mod+5".action."focus-workspace" = 5;
      "Mod+6".action."focus-workspace" = 6;
      "Mod+7".action."focus-workspace" = 7;
      "Mod+8".action."focus-workspace" = 8;
      "Mod+9".action."focus-workspace" = 9;
      "Mod+Shift+1".action."move-column-to-workspace" = 1;
      "Mod+Shift+2".action."move-column-to-workspace" = 2;
      "Mod+Shift+3".action."move-column-to-workspace" = 3;
      "Mod+Shift+4".action."move-column-to-workspace" = 4;
      "Mod+Shift+5".action."move-column-to-workspace" = 5;
      "Mod+Shift+6".action."move-column-to-workspace" = 6;
      "Mod+Shift+7".action."move-column-to-workspace" = 7;
      "Mod+Shift+8".action."move-column-to-workspace" = 8;
      "Mod+Shift+9".action."move-column-to-workspace" = 9;

      "Mod+WheelScrollDown" = {
        cooldown-ms = 150;
        action."focus-workspace-down" = [ ];
      };
      "Mod+WheelScrollUp" = {
        cooldown-ms = 150;
        action."focus-workspace-up" = [ ];
      };
      "Mod+Ctrl+WheelScrollDown" = {
        cooldown-ms = 150;
        action."move-column-to-workspace-down" = [ ];
      };
      "Mod+Ctrl+WheelScrollUp" = {
        cooldown-ms = 150;
        action."move-column-to-workspace-up" = [ ];
      };
      "Mod+WheelScrollRight".action."focus-column-right" = [ ];
      "Mod+WheelScrollLeft".action."focus-column-left" = [ ];
      "Mod+Shift+WheelScrollDown".action."focus-column-right" = [ ];
      "Mod+Shift+WheelScrollUp".action."focus-column-left" = [ ];
      "Mod+Ctrl+WheelScrollRight".action."move-column-right" = [ ];
      "Mod+Ctrl+WheelScrollLeft".action."move-column-left" = [ ];
      "Mod+Ctrl+Shift+WheelScrollDown".action."move-column-right" = [ ];
      "Mod+Ctrl+Shift+WheelScrollUp".action."move-column-left" = [ ];

      "XF86AudioRaiseVolume".action.spawn = [
        "wpctl"
        "set-volume"
        "@DEFAULT_AUDIO_SINK@"
        "5%+"
      ];
      "XF86AudioLowerVolume".action.spawn = [
        "wpctl"
        "set-volume"
        "@DEFAULT_AUDIO_SINK@"
        "5%-"
      ];
      "XF86AudioMute".action.spawn = [
        "wpctl"
        "set-mute"
        "@DEFAULT_AUDIO_SINK@"
        "toggle"
      ];
      "XF86MonBrightnessUp" = {
        "allow-when-locked" = true;
        action.spawn = [ "/home/lynimbus/.config/niri/backlight-up.sh" ];
      };
      "XF86MonBrightnessDown" = {
        "allow-when-locked" = true;
        action.spawn = [
          "sh"
          "-c"
          "brightnessctl set 10%- 2>/dev/null || ddcutil setvcp 10 - 10"
        ];
      };

      "Mod+Shift+S".action."screenshot" = {
        "show-pointer" = false;
      };
      "Print".action."screenshot" = {
        "show-pointer" = false;
      };
      "Ctrl+Print".action."screenshot-screen" = {
        "show-pointer" = false;
      };
      "Alt+Print".action."screenshot-window" = {
        "show-pointer" = false;
      };
    };
  };

  xdg.configFile."niri/effects.kdl".source = ./config/niri/effects_normal.kdl;
  xdg.configFile."niri/effects_normal.kdl".source = ./config/niri/effects_normal.kdl;
  xdg.configFile."niri/effects_eyecare.kdl".source = ./config/niri/effects_eyecare.kdl;
  xdg.configFile."niri/toggle-eyecare.sh".source = ./config/niri/toggle-eyecare.sh;
  xdg.configFile."niri/niri-scratch-toggle.sh".source = ./config/niri/niri-scratch-toggle.sh;
  xdg.configFile."niri/backlight-up.sh".source = ./config/niri/backlight-up.sh;

  xdg.configFile."noctalia/templates/gtk-3.0.css".source = ./config/noctalia/templates/gtk-3.0.css;
  xdg.configFile."noctalia/templates/gtk-4.0.css".source = ./config/noctalia/templates/gtk-4.0.css;

  programs.noctalia = {
    enable = true;
    settings = ./config/noctalia/noctalia-config.toml;
  };

  programs.nushell = {
    enable = true;

    settings = {
      show_banner = false;
      edit_mode = "vi";
      table.mode = "rounded";
      history.file_format = "sqlite";
      completions.external = {
        enable = true;
        max_results = 200;
      };
    };

    environmentVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };

    shellAliases = {
      ll = "ls -la";
      la = "ls -a";
      g = "git";
      j = "jj";
    };
  };

  programs.dsh = {
    enable = true;

    profiles = {
      tui.bundles = [ pkgs.dsh.bundles.tui ];
      web.bundles = [ pkgs.dsh.bundles.web-app ];
    };

    defaultProfile = config.programs.dsh.profiles.tui.materializedName;
  };

  services.dsh = {
    enable = true;
    profile = config.programs.dsh.profiles.web.materializedName;
    listenAddress = "127.0.0.1";
    port = 3080;
  };

  programs.pi-coding-agent = {
    enable = true;
    context = ./pi-agent/AGENTS.md;
    extraPackages = [ pkgs.nodejs ];

    settings = {
      defaultProvider = "lxiic";
      defaultModel = "claude-opus-5-max";
      defaultThinkingLevel = "max";
      hideThinkingBlock = false;
      theme = "dark";
      quietStartup = false;
      collapseChangelog = true;
      enableInstallTelemetry = false;
      defaultProjectTrust = "ask";
      compaction = {
        enabled = true;
        reserveTokens = 32768;
        keepRecentTokens = 50000;
      };
      branchSummary = {
        reserveTokens = 32768;
        skipPrompt = false;
      };
      retry = {
        enabled = true;
        maxRetries = 3;
        baseDelayMs = 2000;
        provider = {
          timeoutMs = 3600000;
          maxRetries = 0;
          maxRetryDelayMs = 60000;
        };
      };
      steeringMode = "one-at-a-time";
      followUpMode = "one-at-a-time";
      transport = "auto";
      httpIdleTimeoutMs = 300000;
      websocketConnectTimeoutMs = 15000;
      terminal = {
        showImages = true;
        imageWidthCells = 60;
        clearOnShrink = true;
        showTerminalProgress = true;
      };
      images = {
        autoResize = true;
        blockImages = false;
      };
      markdown = {
        codeBlockIndent = "  ";
        mermaid = "final";
      };
      enableSkillCommands = true;
      warnings.anthropicExtraUsage = false;
      packages = [
        "npm:pi-web-access"
        "npm:@juicesharp/rpiv-ask-user-question"
      ];
      tuiMode = "regular";
      doubleEscapeAction = "tree";
      treeFilterMode = "all";
      fullscreenScrollbar = "auto";
      fullscreenExitOutput = "resume-hint";
      showCacheMissNotices = false;
      showHardwareCursor = true;
    };

    models.providers = {
      lxiid = {
        api = "openai-completions";
        baseUrl = "https://sub2.lxii.cc/v1";
        models = [
          {
            id = "deepseek-v4-flash";
            name = "DeepSeek V4 Flash";
            reasoning = true;
            input = [ "text" ];
            thinkingLevelMap.max = "max";
            contextWindow = 1000000;
            maxTokens = 384000;
            compat = {
              supportsStore = false;
              supportsDeveloperRole = false;
              supportsReasoningEffort = true;
              maxTokensField = "max_tokens";
              requiresReasoningContentOnAssistantMessages = true;
              thinkingFormat = "deepseek";
            };
          }
          {
            id = "kimi-k3";
            name = "Kimi K3";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            thinkingLevelMap.max = "max";
            contextWindow = 1048576;
            maxTokens = 131072;
            compat = {
              supportsStore = false;
              supportsDeveloperRole = false;
              supportsReasoningEffort = true;
              maxTokensField = "max_tokens";
              requiresReasoningContentOnAssistantMessages = true;
              thinkingFormat = "deepseek";
            };
          }
        ];
      };
      lxiic = {
        api = "anthropic-messages";
        baseUrl = "https://sub2.lxii.cc";
        models = [
          {
            id = "claude-opus-5-max";
            name = "Claude Opus 5 Max";
            reasoning = true;
            input = [
              "text"
              "image"
            ];
            thinkingLevelMap.max = "max";
            compat.forceAdaptiveThinking = true;
            contextWindow = 1000000;
            maxTokens = 128000;
          }
        ];
      };
    };
  };

  home.file = {
    ".pi/agent/extensions".source = ./pi-agent/extensions;
    ".pi/agent/skills/nixos".source = inputs.nixos-ai-skill;
  }
  // lib.mapAttrs' (name: _: {
    name = ".pi/agent/skills/${name}";
    value.source = ./pi-agent/skills + "/${name}";
  }) (builtins.readDir ./pi-agent/skills);

}
