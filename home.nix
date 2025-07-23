{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./home
  ];

  home.username = "lantianx";
  home.homeDirectory = "/home/lantianx";

  # 直接将当前文件夹的配置文件，链接到 Home 目录下的指定位置
  # home.file.".config/i3/wallpaper.jpg".source = ./wallpaper.jpg;

  # https://wiki.archlinux.org.cn/title/Tencent_QQ#Empty_login_page_after_a_hot_update
  home.file.".config/QQ/versions/config.json".source = ./assets/QQ/config.json;

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

  home.packages = with pkgs; [
    fastfetch
    neofetch
    pfetch

    zip
    xz
    unzip
    p7zip

    ripgrep
    jq
    yq-go
    eza
    fzf
    xclip
    lazygit
    lazyjj
    jjui
    jj-fzf
    mergiraf
    delta

    mtr
    iperf3
    dnsutils
    ldns
    aria2
    socat
    nmap
    ipcalc

    cowsay
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd
    gnupg

    nix-output-monitor

    hugo
    glow

    btop
    iotop
    iftop

    strace
    ltrace
    lsof

    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils

    localsend
    vscode
    telegram-desktop
    qq
    wechat
    motrix
  ];

  programs.helix = {
    enable = true;
    defaultEditor = true;
  };

  xdg.configFile."helix" = {
    source = ./assets/helix;
    recursive = true;
    executable = true;
  };

  programs.git = {
    enable = true;
    userName = "lantianx";
    userEmail = "128837704+lantianx233@users.noreply.github.com";
    extraConfig = {
      merge = {conflictStyle = "diff3";};
    };
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      git.sign-on-push = true;
      ui = {
        default-command = "log";
        editor = "hx";
        # paginate = "never";
        pager = "delta";
        diff-formatter = ":git";
        merge-editor = "mergiraf";
      };
      user = {
        email = "128837704+lantianx233@users.noreply.github.com";
        name = "lantianx";
      };
    };
  };

  programs.ssh = {
    enable = true;
    forwardAgent = true;
    matchBlocks = {
      "github.com" = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/id_ed25519";
      };
    };
  };

  programs.starship = {
    enable = true;
    settings = {
      add_newline = false;
      aws.disabled = true;
      gcloud.disabled = true;
      line_break.disabled = true;
    };
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.bash = {
    enable = true;
    initExtra = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

  programs.fish = {
    enable = true;
    shellInit = ''
      set -g fish_greeting
    '';
    shellAliases = {
      sw = "sudo nixos-rebuild switch --flake ~/dotfiles#nixos";
      error = "journalctl -b -p err";
      v = "nvim";
      c = "clear";
      cd = "z";
      rsync = "rsync -avhzP";
      rm = "rm -I";
      cp = "cp -irv";
      mv = "mv -iv";
      bye = "shutdown now";
      la = "ls -lah";
    };
    functions = {
      relpath = {
        body = ''
          if test (count $argv) -ne 1
                   echo "Usage: relpath /path/to/target"
                   return 1
                 end
                 realpath --relative-to=(pwd) $argv[1]
        '';
      };
    };
  };

  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    #fcitx5.waylandFrontend = true;
    fcitx5.addons = with pkgs; [
      (fcitx5-rime.override {
        rimeDataPkgs = with pkgs.nur.repos.linyinfeng.rimePackages;
          withRimeDeps [
            rime-ice
          ];
      })
      fcitx5-gtk
      fcitx5-configtool
    ];
  };

  home.file.".local/share/fcitx5/rime/default.custom.yaml".source = ./assets/rime/default.custom.yaml;

  home.stateVersion = "25.05";
}
