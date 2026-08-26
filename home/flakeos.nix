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
    inputs.kickstart-nixvim.homeManagerModules.default
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";

  home.packages = with pkgs; [
    ripgrep
    fzf
    jq
    just
    nvd
    gh
    jjui
    pi-coding-agent
    ungoogled-chromium
    ayugram-desktop
    qq

    # --- git/jj 增强依赖（delta 做 pager，mergiraf 做 jj merge editor）---
    delta
    mergiraf

    # --- CLI 工具组（旧配置合入）---
    fd
    eza
    bat
    fastfetch
    zoxide

    # --- 压缩 / 媒体工具（旧配置合入）---
    zip
    unzip
    p7zip
    xz
    ffmpeg
    imagemagick
    poppler

    # --- rnnoise 降噪：配置文件里引用了这俩的 store 路径，装进 profile 防止被 GC ---
    ladspaPlugins
    rnnoise-plugin

    # --- niri 运行时依赖（配置与脚本见下方 xdg.configFile niri 块）---
    # noctalia 不走 home.packages：见下方 programs.noctalia。nixpkgs 的
    # noctalia-shell 4.7.7 是旧 Quickshell 版（二进制叫 noctalia-shell），
    # 与 niri 配置里的 spawn "noctalia" / noctalia msg 不兼容，别装它。
    brightnessctl # 内屏背光（backlight-up.sh）
    ddcutil # 外接显示器 DDC 背光回退（backlight-up.sh）
    wlsunset # 护眼模式色温（toggle-eyecare.sh）
    tmux # scratchpad 终端后端（niri-scratch-toggle.sh）
    fish # scratchpad 里锁定窗口标题用（与 Arch 上行为一致）
    libnotify # notify-send（toggle-eyecare.sh 的 OSD 通知）
    # 文件管理器（Mod+E 打开 thunar；gvfs/tumbler 负责挂载与缩略图，与 Arch 上一致）
    thunar
    gvfs
    tumbler
  ];

  # ghostty 主题与窗口偏好（旧配置合入；字体走系统装好的 Nerd Font）
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

  # zed 主题与编辑偏好（旧配置合入：One Dark + vim 模式 + 关遥测）
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

  # yazi 终端文件管理器（旧配置全套合入：nord 主题 + 插件 + 键位）
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
        # push 时自动签名（旧配置合入）
        sign-on-push = true;
        # wip:/private: 前缀的 commit 不进推送、可被自动重写（旧配置合入）
        private-commits = "description(glob:'wip:*') | description(glob:'private:*')";
      };
      ui = {
        default-command = "log";
        editor = "nvim";
        # delta 高亮 pager（delta 已在 home.packages）
        pager = "delta";
        # 3-way 冲突用 mergiraf 解决（mergiraf 已在 home.packages）
        merge-editor = "mergiraf";
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

      # delta 渲染 diff（旧配置合入）
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

  # SSH：全局 forwardAgent + github.com 固定身份（旧配置合入）
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

  # direnv + nix-direnv（旧配置合入）
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.zoxide = {
    enable = true;
    enableNushellIntegration = true;
  };

  # nvim 声明式全家桶（kickstart.nixvim，旧配置合入）。
  # 注意：系统的 environment.systemPackages 里还有裸 neovim，
  # 用户 profile 里的 nvim 优先，systemPackages 那份只作兜底。
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
  };

  # rnnoise 麦克风降噪（自动增益 + 降噪，旧配置合入）。
  # 依赖的 ladspaPlugins / rnnoise-plugin 已在 home.packages 里。
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

  # niri 声明式配置（niri-flake homeModules.config 托管，经 nixosModules.niri
  # 注入，构建期用 programs.niri.package＝pkgs.niri-glass（带 liquid-glass 补丁）
  # 跑 `niri validate` 校验后才写入 ~/.config/niri/config.kdl）。
  # 配置 95% 走 programs.niri.settings（结构化 Nix）——monitor/input/layout/
  # animations/rules/binds/主段落全在下面，生成的 config.kdl 自包含，不再
  # include 任何普通分片（旧 *.kdl 分片文件已删除）。
  #
  # 唯一无法进 settings 的是 liquid-glass：Niri-glass 补丁专有参数，官方 schema
  # 的 background-effect 只有 blur/xray。因此「全局磨砂规则 + 各应用半透明/
  # 毛玻璃外观规则」放在可替换片段 ~/.config/niri/effects.kdl，经 settings.
  # includes 以 `include optional=true "effects.kdl"` 引入。include 总是生成在
  # config.kdl 最前 → 这些全局规则先于所有 settings 的 window-rules，后者按需
  # 覆盖（与原 effects→rules 的顺序语义一致）。optional=true 是因为构建期校验
  # 时文件还没落盘；运行期由 niri 真正 include（文件由 xdg.configFile 托管）。
  #
  # ⚠️ top-level blur 节点固定由 settings 生成，任何 effects 片段里不能出现
  # blur 节点（重复节点 niri 会拒载）。外观类应用规则放在 effects 片段里，是
  # 为了护眼模式能用文件切换整体替换它们（settings 无运行期切换入口）。
  #
  # 护眼 = toggle-eyecare.sh 把 effects.kdl 符号链接切到 effects_normal.kdl /
  # effects_eyecare.kdl 后 `niri msg action load-config-file` 重载（--sync 在
  # 启动时按 symlink 状态复原并对齐 wlsunset 色温）。
  programs.niri.settings = {
    includes = [
      {
        path = "effects.kdl";
        optional = true;
      }
    ];

    # monitor.kdl：内屏 eDP-1/eDP-2 双配置（驱动注册顺序不定，都配上）
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

    # ←── config.kdl 主段落 ─────────────────────────────
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
      # chromium 原生 Wayland 开关（nixpkgs 包装器读这个变量才会加
      # --ozone-platform-hint=auto）。此前未设置 → ungoogled-chromium 走 XWayland，
      # 点自绘标题栏最小化按钮会把窗口卡死（niri 不实现 minimize，X11 客户端
      # 等不到 WM 响应，见 niri-wm/niri#3780 / #4363）。
      NIXOS_OZONE_WL = "1";
    };

    spawn-at-startup = [
      { argv = [ "noctalia" ]; }
      # 护眼开机复原（按 effects.kdl symlink 状态对齐 wlsunset）
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
      # GTK M3 模板冷启重渲染（移植自上游 NyxNiri）
      { sh = "sleep 8; noctalia msg config-reload && noctalia msg templates-apply"; }
    ];

    "hotkey-overlay"."skip-at-startup" = true;
    "prefer-no-csd" = true;
    "screenshot-path" = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

    debug = {
      # niri v26.04 的这个开关是全局 bool 旗标，不是 per-app 列表：裸写 = true =
      # 对所有应用放行「serial 无效/过期」的 xdg-activation 请求（niri 官方为
      # Discord/Telegram 这类客户端准备的开关）。之前写 `[ ]` 会被 niri-flake
      # 渲染成裸旗标（= true），行为就是全局放行——这里显式写成 true 并保留该
      # 行为，让「从启动器点开 zed / 点图标拉起窗口」这类非交互激活仍生效。
      # （zed 日志里的 gpui WARN "activation token received with no pending
      # activation" 是 zed 自身的竞态，与这个开关无关，见 niri 日志排查记录。）
      # 想回 niri 默认严格模式，改 false 或删掉整段即可。
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

    # ←── input__custom__.kdl ─────────────────────────────
    gestures."hot-corners".enable = false;
    input = {
      keyboard.numlock = true;
      # trackpoint 省略：niri 默认启用，settings 表达不了裸 `trackpoint` 节点
      touchpad = {
        tap = true;
        "natural-scroll" = true;
        dwt = true; # 打字时禁用触摸板
        dwtp = true; # 打字时禁用触摸板指针移动
        "disabled-on-external-mouse" = true;
      };
      mouse."accel-speed" = -0.72;
    };

    # ←── layout.kdl ─────────────────────────────
    # layout.kdl 顶部那条全局 window-rule（圆角/裁切/边框）在下方
    # "window-rules" 列表的第一条（必须排最前，让后面的规则能覆盖）。

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
        # settings 的 focus-ring 用 toggle 语义：enable=false 时只输出 `off`，
        # width/active/inactive/urgent 颜色等内部选项会被整体丢弃（与手写
        # `focus-ring { off width 0 active-color … }` 行为等价——环关闭时这些
        # 参数不参与渲染）。想恢复环时再补 width/颜色。
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

    # ←── animations.kdl ─────────────────────────────
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

    # top-level blur：由 settings 生成（effects 片段里不能再有 blur 节点）
    blur = {
      enable = true;
      offset = 2.3;
      noise = 0.001;
      saturation = 2;
    };

    # ←── rules.kdl（结构类规则；透明/毛玻璃外观规则在 effects 片段）──
    "layer-rules" = [
      # noctalia/mpvpaper 壁纸层放进 backdrop
      {
        matches = [ { namespace = "^noctalia-wallpaper*"; } ];
        "place-within-backdrop" = true;
      }
      {
        matches = [ { namespace = "^mpvpaper$"; } ];
        "place-within-backdrop" = true;
      }
      # noctalia 状态栏命名空间：v5.0.0 是 noctalia-bar-bar，nixpkgs 的
      # 5.0.0-beta.9 是 noctalia-bar-default（都匹配，兼容两种版本）
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
      # layout.kdl 顶部那条全局规则（圆角/裁切/边框）——必须排最前，
      # 后面的规则按需覆盖它。
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
      # 浮动终端（Mod+Shift+Return 启动，ghostty --class=com.ghostty.float）
      # rule: ghostty-float
      {
        matches = [ { "app-id" = "com.ghostty.float"; } ];
        "open-floating" = true;
      }
      # rule: noctalia-float
      {
        matches = [ { "app-id" = "dev.noctalia.Noctalia"; } ];
        "open-floating" = true;
      }
      # 系统设置类对话框：半宽平铺
      # rule: settings-dialogs
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
      # 计算器/剪贴板/蓝曼等小工具：浮动（毛玻璃外观在 effects 片段）
      # rule: small-tools-float
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
      # rule: nautilus-border
      {
        matches = [ { "app-id" = "^org\\.gnome\\.Nautilus$"; } ];
        "draw-border-with-background" = false;
      }
      # rule: zen-border
      {
        matches = [ { "app-id" = "app.zen_browser.zen"; } ];
        "draw-border-with-background" = false;
      }
      # steam 通知 toast：右下角，不抢焦点
      # rule: steam-toasts
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
      # rule: zoom-float
      {
        matches = [ { "app-id" = "zoom"; } ];
        "open-floating" = true;
      }
      # wine 整窗：浮动 + 全宽（blur 保持关，两种模式一致）
      # rule: wine
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
      # Wine 系统托盘/占位横幅：藏到屏幕外
      # rule: wine-tray-invisible
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
          # niri kdl 里 relative-to 缺省即 top-left，settings 强制显式
          relative-to = "top-left";
        };
        shadow.enable = false;
      }
      # chromium 系（ungoogled-chromium）：完全不透明 + 关毛玻璃
      # rule: chromium-opaque
      {
        matches = [ { "app-id" = "^(chromium|chromium-browser|org\\.chromium\\.\\w+)$"; } ];
        opacity = 1.0;
        "background-effect".blur = false;
      }
      # 游戏：强制无特效
      # rule: games-performance
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
      # 画中画：全工作区悬浮（Mod+拖拽可移动）
      # rule: pip-floating
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
      # 视频软件：不透明
      # rule: video-opaque
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
      # 图片/视频查看器（中英文标题 + app-id 双保险）
      # rule: viewers-float
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
      # rule: steam-friends-width
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
      # QQ 资料卡 / 天气窗口不抢焦点
      # rule: qq-no-focus
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
      # rule: qq-chatlog-float
      {
        matches = [
          {
            "app-id" = "QQ";
            title = "群聊的聊天记录";
          }
        ];
        "open-floating" = true;
      }
      # rule: imv-float
      {
        matches = [ { "app-id" = "imv"; } ];
        "open-floating" = true;
      }
      # rule: ente-float
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
      # Scratchpad 终端（Mod+Grave toggle；ghostty 无 --app-id，用标题匹配）
      # rule: scratchpad
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

    # ←── binds.kdl ─────────────────────────────
    binds = {
      # 会话与系统控制
      "Mod+Tab" = {
        repeat = false; # 禁止长按切换概览
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

      # 应用启动与 Noctalia
      "Mod+Return".action.spawn = [ "ghostty" ];
      "Mod+Shift+Return".action.spawn = [
        "ghostty"
        "--class=com.ghostty.float"
      ];
      "Mod+E".action.spawn = [ "thunar" ];
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

      # 焦点导航与窗口移动
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

      # 窗口布局与尺寸
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

      # 工作区管理 (1-9)
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

      # 鼠标与滚轮
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

      # 多媒体与硬件
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

      # 截图
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

  # config.kdl 由上方 settings 生成；这里只托管运行期按位落盘的文件：
  # effects 三件套（effects.kdl 是 settings.includes 引用的符号链接目标，
  # toggle-eyecare.sh 在 normal/eyecare 之间切换它；home-manager 部署会
  # 重置回 normal）+ 三个脚本（binds 里被引用）。
  xdg.configFile = {
    "niri/effects.kdl".source = ./config/niri/effects_normal.kdl;
    "niri/effects_normal.kdl".source = ./config/niri/effects_normal.kdl;
    "niri/effects_eyecare.kdl".source = ./config/niri/effects_eyecare.kdl;
    "niri/toggle-eyecare.sh".source = ./config/niri/toggle-eyecare.sh;
    "niri/niri-scratch-toggle.sh".source = ./config/niri/niri-scratch-toggle.sh;
    "niri/backlight-up.sh".source = ./config/niri/backlight-up.sh;

    # noctalia GTK Material You 模板源文件（随上游 NyxNiri 移植）：
    # noctalia-config.toml 里注册为 theme.templates.user.nyxniri_gtk3/gtk4，
    # noctalia 在壁纸/明暗切换时读取这里渲染到 ~/.config/gtk-{3,4}.0/gtk.css。
    "noctalia/templates/gtk-3.0.css".source = ./config/noctalia/templates/gtk-3.0.css;
    "noctalia/templates/gtk-4.0.css".source = ./config/noctalia/templates/gtk-4.0.css;
  };

  # noctalia v5：Wayland shell（顶栏/启动器/锁屏/剪贴板），niri 配置大量引用。
  # 走 home-manager 自带模块，package 默认 pkgs.noctalia（nixpkgs 的 5.0.0-beta.9，
  # 与 Arch 上的 v5.0.0 同线、IPC 兼容）。启动仍由 niri 的 spawn-at-startup "noctalia"
  # 负责（与 Arch 上行为一致），所以不开 systemd 服务，避免双启动。
  # settings 接受 attrset / 原始 TOML 字符串 / .toml 文件路径：构建期经
  # `noctalia config validate` 校验后写入 ~/.config/noctalia/config.toml。
  # 配置内容移植自上游 NyxNiri（configs/noctalia/noctalia-config.toml），
  # 按本机裁剪（去掉 mpvpaper/echolyrics 插件与 fcitx5 模板注册等），
  # 文件头注释里列了所有改动点。注意运行时设置面板的改动会写进
  # ~/.local/state/noctalia/settings.toml 并覆盖这里的值，属预期行为。
  programs.noctalia = {
    enable = true;
    settings = ./config/noctalia/noctalia-config.toml;
  };

  # 默认 shell 是 nushell（登录 shell 在 hosts/flakeos/configuration.nix 的
  # users.users.lynimbus.shell 里设置）。这里的配置由 home-manager 托管：
  # 生成的 ~/.config/nushell/config.nu 是指向 /nix/store 的只读符号链接，
  # 想改配置改这里再部署，别手改那个文件。
  programs.nushell = {
    enable = true;

    # 每项会被拍平成 $env.config.<key> = <value> 追加进 config.nu，
    # 未设置的键沿用 nushell 内置默认值。
    settings = {
      show_banner = false;
      edit_mode = "vi"; # nvim 用户习惯 vi 键位；想换回 emacs 改成 "emacs"
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

  # dsh（DeepSeek Harness）。模块自己把组合后的包加进 home.packages，
  # 不要再往上面的 home.packages 里手写 dsh。
  # 裸 pkgs.dsh 的 defaultBundles 已经是 [ headless web-app ]，base 层总是自动
  # 注入，所以 profile 里只用写各自特有的 bundle。
  # profile key 会被物化为 $DSH_HOME/profiles/nix-<key>，引用时一律走
  # materializedName，不要硬写 "nix-tui" 这种字符串。
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

  # home.file.".config/foo/config.toml".source = ../config/foo.toml;
  # home.file.".bashrc".text = "export EDITOR=vim\n";

  # home.sessionPath = [ "$HOME/.local/bin" ];

  home.stateVersion = "26.05";
}
