{
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
    dig
    android-tools

    # --- 语言工具链（追踪最新构庺）---
    # zig：zig-overlay 的 master 版本（官方每日构建，跟随 flake.lock）
    zigpkgs.master
    # koka：nixpkgs-unstable 的 release 版本（跟随 nixpkgs 通道）
    koka

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
    # 官方 flake（zed-editor input）锁最新 release tag，从 zed.cachix 秒装。
    # 升级方法：改 flake.nix 中 zed-editor 的 ref 为新 tag →
    #   nix flake lock --update-input zed-editor → just switch
    package = pkgs.zed-prebuilt;
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

}
