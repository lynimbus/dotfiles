{
  config,
  inputs,
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

  # niri 窗口管理器配置（旧配置从 tmp/dotfiles 合入，带 liquid-glass 液态玻璃补丁）。
  # niri 本体 = niri-glass（flake input，见 flake.nix / configuration.nix），这里只托管
  # 配置与脚本：文件原样来自旧仓 origin/backup 分支（effects_normal.kdl 含 liquid-glass
  # 参数，护眼模式 effects_eyecare.kdl 整体替换）。
  # effects.kdl 是护眼切换的符号链接源：托管为 normal 内容作首次启动初始态，
  # toggle-eyecare.sh 运行时用 ln -sfn 接管（下次部署会重置回 normal，属预期）。
  # 注意：noctalia 相关绑定依赖 noctalia v5（见下方 programs.noctalia）。
  xdg.configFile = {
    "niri/config.kdl".source = ./config/niri/config.kdl;
    "niri/monitor.kdl".source = ./config/niri/monitor.kdl;
    "niri/effects_normal.kdl".source = ./config/niri/effects_normal.kdl;
    "niri/effects_eyecare.kdl".source = ./config/niri/effects_eyecare.kdl;
    "niri/effects.kdl".source = ./config/niri/effects_normal.kdl;
    "niri/input__custom__.kdl".source = ./config/niri/input__custom__.kdl;
    "niri/layout.kdl".source = ./config/niri/layout.kdl;
    "niri/animations.kdl".source = ./config/niri/animations.kdl;
    "niri/rules.kdl".source = ./config/niri/rules.kdl;
    "niri/binds.kdl".source = ./config/niri/binds.kdl;
    "niri/__custom__.kdl".source = ./config/niri/__custom__.kdl;
    "niri/toggle-eyecare.sh".source = ./config/niri/toggle-eyecare.sh;
    "niri/niri-scratch-toggle.sh".source = ./config/niri/niri-scratch-toggle.sh;
    "niri/backlight-up.sh".source = ./config/niri/backlight-up.sh;
    "niri/close-focused.sh".source = ./config/niri/close-focused.sh;

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
