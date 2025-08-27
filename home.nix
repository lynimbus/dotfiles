{
  pkgs,
  lib,
  inputs,
  ...
}:
{
  imports = [
    (inputs.import-tree ./home)
  ];

  home.username = "lantianx";
  home.homeDirectory = "/home/lantianx";

  # 直接将当前文件夹的配置文件，链接到 Home 目录下的指定位置
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # 递归将某个文件夹中的文件，链接到 Home 目录下的指定位置
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # 递归整个文件夹
  #   executable = true;  # 将其中所有文件添加「执行」权限
  # };

  # 直接以 text 的方式，在 nix 配置文件中硬编码文件内容
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  xdg.configFile.".ripgreprc".source = ./assets/ripgreprc;

  home.packages = with pkgs; [
    broot
    fastfetch
    hyfetch

    zip
    xz
    unzip
    p7zip

    ffmpeg
    jq
    poppler
    fd
    ripgrep
    fzf
    zoxide
    resvg
    imagemagick
    wl-clipboard
    eza
    devenv

    lazygit
    lazyjj
    jjui
    jj-fzf
    mergiraf
    delta

    vscode-fhs
    zed-editor
    telegram-desktop
    qq
    motrix
  ];

  services.flameshot = {
    enable = true;
    settings = {
      General = {
        uiColor = "#ff78c5";
        disabledTrayIcon = true;
        useGrimAdapter = true;
        showHelp = false;
        showSidePanelButton = false;
        showDesktopNotification = false;
        showAbortNotification = false;
        showStartupLaunchMessage = false;
      };
    };
  };

  programs.kitty = {
    enable = true;
    font = {
      name = "JetBrainsMono Nerd Font Mono";
      size = 14;
    };
    themeFile = "Dracula";
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.git = {
    enable = true;
    userName = "lantianx";
    userEmail = "lantianx233@gmail.com";
    extraConfig = {
      merge = {
        conflictStyle = "diff3";
      };
    };
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      git.sign-on-push = true;
      ui = {
        default-command = "log";
        editor = "nvim";
        # paginate = "never";
        pager = "delta";
        diff-formatter = ":git";
        merge-editor = "mergiraf";
      };
      user = {
        email = "lantianx233@gmail.com";
        name = "lantianx";
      };
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
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

  programs.starship = {
    enable = true;
  };
  xdg.configFile."starship.toml".source = ./assets/starship.toml;

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.fish = {
    enable = true;
    shellInit = ''
      set -g fish_greeting
    '';
    shellAliases = {
      error = "journalctl -b -p err";
      v = "nvim";
      c = "clear";
      cd = "z";
      bye = "shutdown now";
      ls = "eza";
      ll = "eza -lh";
      la = "eza -lah";
    };
    functions = {
      y = {
        body = ''
          set tmp (mktemp -t "yazi-cwd.XXXXXX")
          yazi $argv --cwd-file="$tmp"
          if read -z cwd < "$tmp"; and [ -n "$cwd" ]; and [ "$cwd" != "$PWD" ]
            builtin cd -- "$cwd"
          end
          rm -f -- "$tmp"
        '';
      };
    };
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      (fcitx5-rime.override {
        rimeDataPkgs =
          with pkgs.nur.repos.linyinfeng.rimePackages;
          withRimeDeps [
            rime-ice
          ];
      })
      fcitx5-gtk
      fcitx5-configtool
    ];
  };
  home.file.".local/share/fcitx5/rime/default.custom.yaml".source = ./assets/rime/default.custom.yaml;

  # https://wiki.archlinux.org.cn/title/Tencent_QQ#Empty_login_page_after_a_hot_update
  home.activation = {
    qqRollbackScript = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.bash}/bin/bash ${builtins.toPath ./assets/QQ/qq-version-rollback.sh}
    '';
  };

  home.stateVersion = "25.05";
}
