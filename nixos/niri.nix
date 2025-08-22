{
  pkgs,
  inputs,
  username,
  ...
}:
{
  services.displayManager.ly = {
    enable = true;
    x11Support = false;
  };

  services.desktopManager.plasma6.enable = true;

  programs.niri.enable = true;
  nixpkgs.overlays = [ inputs.niri.overlays.niri ];
  programs.niri.package = pkgs.niri-unstable;
  environment.variables.NIXOS_OZONE_WL = "1";
  environment.systemPackages = with pkgs; [
    wl-clipboard
    wayland-utils
    libsecret
    cage
    gamescope
    xwayland-satellite-unstable
    brightnessctl
    ddcutil
    cliphist
    obs-studio
  ];

  home-manager.users.${username} =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      imports = [ inputs.dankMaterialShell.homeModules.dankMaterialShell ];

      programs.niri.settings = {
        xwayland-satellite = {
          enable = true;
          path = "${lib.getExe pkgs.xwayland-satellite-unstable}";
        };
        outputs."eDP-1" = {
          focus-at-startup = true;
          variable-refresh-rate = true;
        };
        input = {
          keyboard = {
            numlock = true;
            xkb = {
              layout = "us";
              model = "pc104";
              options = "compose:ralt,ctrl:nocaps";
            };
          };
          touchpad = {
            dwt = true;
            scroll-method = "two-finger";
            tap-button-map = "left-right-middle";
          };
          mouse = {
            accel-profile = "flat";
          };
          warp-mouse-to-focus.enable = false;
          focus-follows-mouse.enable = false;
        };
        layout = {
          gaps = 6;
          preset-column-widths = [
            { proportion = 1. / 3.; }
            { proportion = 1. / 2.; }
            { proportion = 2. / 3.; }
          ];
          focus-ring = {
            enable = false;
            width = 2;
            active.color = "#4DA6FF";
          };
          border = {
            enable = true;
            width = 2;
            active.color = "#4DA6FF";
            inactive.color = "#6C7A89";
          };
          shadow = {
            enable = true;
            softness = 10;
            spread = 3;
            offset = {
              x = 0;
              y = 2;
            };
            draw-behind-window = false;
            color = "#00000080";
            inactive-color = "#00000060";
          };
          insert-hint = {
            enable = true;
            display = {
              gradient = {
                from = "#ffbb6680";
                to = "#ffc88080";
                angle = 45;
                relative-to = "workspace-view";
              };
            };
          };
          tab-indicator = {
            enable = true;
            hide-when-single-tab = true;
            place-within-column = true;
            gap = 5;
            width = 4;
            length = {
              total-proportion = 1.0;
            };
            position = "left";
            gaps-between-tabs = 2;
            corner-radius = 8;
            active = {
              color = "bf616a";
            };
            inactive = {
              color = "d08770";
            };
          };
        };
        workspaces = {
          "01".name = "common";
          "02".name = "chat";
          "03".name = "game";
        };
        prefer-no-csd = true;
        spawn-at-startup = [
          {
            command = [
              "bash"
              "-c"
              "wl-paste --watch cliphist store &"
            ];
          }
          {
            command = [
              "fcitx5"
              "-d"
              "--replace"
            ];
          }
        ];
        hotkey-overlay.skip-at-startup = true;
        environment = {
          XDG_CURRENT_DESKTOP = "niri";
          DISPLAY = ":0";
          XDG_SESSION_TYPE = "wayland";
          QT_QPA_PLATFORM = "wayland";
          GDK_BACKEND = "wayland";
          CLUTTER_BACKEND = "wayland";
          MOZ_ENABLE_WAYLAND = "1";
          QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
          ELECTRON_OZONE_PLATFORM_HINT = "auto";
          QT_QPA_PLATFORMTHEME = "qt5ct";
          QT_QPA_PLATFORMTHEME_QT6 = "qt6ct";

          GTK_IM_MODULE = "fcitx";
          QT_IM_MODULE = "fcitx";
          XMODIFIERS = "@im=fcitx";
          SDL_IM_MODULE = "fcitx";
          GLFW_IM_MODULE = "fcitx";

          LANG = "zh_CN.UTF-8";
        };
        animations = {
          enable = true;
          slowdown = 2;
          window-open = {
            kind = {
              easing = {
                duration-ms = 200;
                curve = "linear";
              };
            };
            custom-shader = ''
              vec4 expanding_circle(vec3 coords_geo, vec3 size_geo) {

              vec3 coords_tex = niri_geo_to_tex * coords_geo;
              vec4 color = texture2D(niri_tex, coords_tex.st);
              vec2 coords = (coords_geo.xy - vec2(0.5, 0.5)) * size_geo.xy * 2.0;
              coords = coords / length(size_geo.xy);
              float p = niri_clamped_progress;
              if (p * p <= dot(coords, coords))
              color = vec4(0.0);

              return color;
              }

              vec4 open_color(vec3 coords_geo, vec3 size_geo) {
              return expanding_circle(coords_geo, size_geo);
              }
            '';
          };
          window-close = {
            kind = {
              easing = {
                duration-ms = 250;
                curve = "linear";
              };
            };
            custom-shader = ''
              vec4 fall_and_rotate(vec3 coords_geo, vec3 size_geo) {

              float progress = niri_clamped_progress * niri_clamped_progress;
              vec2 coords = (coords_geo.xy - vec2(0.5, 1.0)) * size_geo.xy;
              coords.y -= progress * 1440.0;
              float random = (niri_random_seed - 0.5) / 2.0;
              random = sign(random) - random;
              float max_angle = 0.5 * random;
              float angle = progress * max_angle;
              mat2 rotate = mat2(cos(angle), -sin(angle), sin(angle), cos(angle));
              coords = rotate * coords;
              coords_geo = vec3(coords / size_geo.xy + vec2(0.5, 1.0), 1.0);
              vec3 coords_tex = niri_geo_to_tex * coords_geo;
              vec4 color = texture2D(niri_tex, coords_tex.st);

              return color;
              }

              vec4 close_color(vec3 coords_geo, vec3 size_geo) {
              return fall_and_rotate(coords_geo, size_geo);
              }
            '';
          };
        };
        overview = {
          zoom = 0.25;
          backdrop-color = "#777777";
          workspace-shadow.enable = false;
        };
        window-rules = [
          {
            matches = [ ];
            geometry-corner-radius = {
              top-left = 8.0;
              top-right = 8.0;
              bottom-left = 8.0;
              bottom-right = 8.0;
            };
            clip-to-geometry = true;
          }

          {
            matches = [ ];
            # block-out-from = "screen-capture";
          }

          {
            matches = [
              { is-active = true; }
              { is-active = false; }
            ];
            draw-border-with-background = false;
            opacity = 0.85;
          }

          {
            matches = [
              { app-id = "firefox"; }
            ];
            opacity = 0.95;
          }

          {
            matches = [ ];
            opacity = 1.0;
          }

          {
            matches = [
              {
                app-id = "kitty";
                title = "kitty-common";
              }
              { app-id = "firefox"; }
            ];
            open-on-workspace = "common";
            open-maximized = true;
            # default-column-width = { fixed = 1300; };
          }

          {
            matches = [
              { app-id = "localsend"; }
              {
                app-id = "kitty";
                title = "kitty-floating";
              }
              {
                app-id = "firefox";
                title = "Opening .*";
              }
            ];
            open-floating = true;
          }

          {
            matches = [
              { app-id = "org.telegram.desktop"; }
              { app-id = "QQ"; }
            ];
            open-on-workspace = "chat";
            default-column-width = {
              fixed = 1300;
            };
          }

          {
            matches = [
              { app-id = "steam"; }
            ];
            open-on-workspace = "game";
            open-floating = true;
          }
        ];
        binds = {
          "Mod+Shift+Slash".action.show-hotkey-overlay = [ ];

          "Mod+Return".action.spawn = [
            "kitty"
            "--title"
            "kitty-common"
          ];
          "Mod+Shift+Return".action.spawn = [
            "kitty"
            "--title"
            "kitty-floating"
          ];
          "Mod+E".action.spawn = "dolphin";
          "Mod+B".action.spawn = "firefox";

          "XF86MonBrightnessUp".action.spawn = [
            "brightnessctl"
            "set"
            "+10"
          ];
          "XF86MonBrightnessDown".action.spawn = [
            "brightnessctl"
            "set"
            "10-"
          ];

          "Mod+Q".action.close-window = [ ];
          "Mod+O".action.toggle-overview = [ ];

          "Mod+W".action.toggle-window-floating = [ ];
          "Mod+Shift+W".action.switch-focus-between-floating-and-tiling = [ ];

          "Mod+Left".action.focus-column-left = [ ];
          "Mod+Right".action.focus-column-right = [ ];
          "Mod+Shift+Left".action.focus-column-first = [ ];
          "Mod+Shift+Right".action.focus-column-last = [ ];

          "Mod+Ctrl+Left".action.move-column-left = [ ];
          "Mod+Ctrl+Right".action.move-column-right = [ ];

          "Mod+Down".action.focus-workspace-down = [ ];
          "Mod+Up".action.focus-workspace-up = [ ];
          "Mod+Ctrl+Down".action.move-column-to-workspace-down = [ ];
          "Mod+Ctrl+Up".action.move-column-to-workspace-up = [ ];

          "Mod+Page_Down".action.focus-workspace-down = [ ];
          "Mod+Page_Up".action.focus-workspace-up = [ ];
          "Mod+Ctrl+Page_Down".action.move-column-to-workspace-down = [ ];
          "Mod+Ctrl+Page_Up".action.move-column-to-workspace-up = [ ];

          "Mod+WheelScrollDown" = {
            action.focus-workspace-down = [ ];
            cooldown-ms = 150;
          };
          "Mod+WheelScrollUp" = {
            action.focus-workspace-up = [ ];
            cooldown-ms = 150;
          };
          "Mod+Ctrl+WheelScrollDown" = {
            action.move-column-to-workspace-down = [ ];
            cooldown-ms = 150;
          };
          "Mod+Ctrl+WheelScrollUp" = {
            action.move-column-to-workspace-up = [ ];
            cooldown-ms = 150;
          };

          "Mod+WheelScrollRight".action.focus-column-right = [ ];
          "Mod+WheelScrollLeft".action.focus-column-left = [ ];
          "Mod+Ctrl+WheelScrollRight".action.move-column-right = [ ];
          "Mod+Ctrl+WheelScrollLeft".action.move-column-left = [ ];

          "Mod+Shift+WheelScrollDown".action.focus-column-right = [ ];
          "Mod+Shift+WheelScrollUp".action.focus-column-left = [ ];
          "Mod+Ctrl+Shift+WheelScrollDown".action.move-column-right = [ ];
          "Mod+Ctrl+Shift+WheelScrollUp".action.move-column-left = [ ];

          "Mod+1".action.focus-workspace = 1;
          "Mod+2".action.focus-workspace = 2;
          "Mod+3".action.focus-workspace = 3;
          "Mod+4".action.focus-workspace = 4;
          "Mod+5".action.focus-workspace = 5;
          "Mod+6".action.focus-workspace = 6;
          "Mod+7".action.focus-workspace = 7;
          "Mod+8".action.focus-workspace = 8;
          "Mod+9".action.focus-workspace = 9;

          "Mod+Ctrl+1".action.move-column-to-workspace = 1;
          "Mod+Ctrl+2".action.move-column-to-workspace = 2;
          "Mod+Ctrl+3".action.move-column-to-workspace = 3;
          "Mod+Ctrl+4".action.move-column-to-workspace = 4;
          "Mod+Ctrl+5".action.move-column-to-workspace = 5;
          "Mod+Ctrl+6".action.move-column-to-workspace = 6;
          "Mod+Ctrl+7".action.move-column-to-workspace = 7;
          "Mod+Ctrl+8".action.move-column-to-workspace = 8;
          "Mod+Ctrl+9".action.move-column-to-workspace = 9;

          "Mod+Tab".action.focus-workspace-previous = [ ];

          "Mod+R".action.switch-preset-column-width = [ ];
          "Mod+F".action.maximize-column = [ ];
          "Mod+Shift+F".action.fullscreen-window = [ ];
          "Mod+C".action.center-column = [ ];

          "Mod+Minus".action.set-column-width = "-5%";
          "Mod+Equal".action.set-column-width = "+5%";

          "Mod+Shift+Minus".action.set-window-height = "-5%";
          "Mod+Shift+Equal".action.set-window-height = "+5%";
          "Mod+Shift+R".action.reset-window-height = [ ];

          "Mod+Alt+0".action.set-column-width = "1200";

          "Print" = {
            action.screenshot = {
              show-pointer = false;
            };
          };
          "Ctrl+Print" = {
            action.screenshot-screen = {
              show-pointer = false;
            };
          };
          "Alt+Print".action.screenshot-window = [ ];
          "Ctrl+F1" = {
            action.screenshot = {
              show-pointer = false;
            };
          };

          "Mod+Shift+P".action.power-off-monitors = [ ];
          "Mod+Shift+Q" = {
            action.quit = {
              skip-confirmation = true;
            };
          };
          "Mod+Z".action.toggle-column-tabbed-display = [ ];
        };
      };

      programs.dankMaterialShell = {
        enable = true;
        enableKeybinds = true;
        enableSystemd = false;
        enableSpawn = true;
      };
    };
}
