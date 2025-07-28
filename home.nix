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

  xdg.configFile.".ripgreprc".source = ./assets/ripgreprc;

  # 递归将某个文件夹中的文件，链接到 Home 目录下的指定位置
  # home.file.".config/i3/scripts" = {
  #   source = ./scripts;
  #   recursive = true;   # 递归整个文件夹
  #   executable = true;  # 将其中所有文件添加「执行」权限
  # };

  xdg.configFile."hypr" = {
    source = ./assets/hypr;
    recursive = true;
    executable = true;
  };

  xdg.configFile."mako" = {
    source = ./assets/mako;
    recursive = true;
    executable = true;
  };

  xdg.configFile."niri" = {
    source = ./assets/niri;
    recursive = true;
    executable = true;
  };

  xdg.configFile."rofi" = {
    source = ./assets/rofi;
    recursive = true;
    executable = true;
  };

  xdg.configFile."waybar" = {
    source = ./assets/waybar;
    recursive = true;
    executable = true;
  };

  # 直接以 text 的方式，在 nix 配置文件中硬编码文件内容
  # home.file.".xxx".text = ''
  #     xxx
  # '';

  home.file.".config/user-dirs.locale".text = "en_US.UTF-8";

  home.packages = with pkgs; [
    broot
    yazi

    fastfetch
    neofetch
    pfetch

    zip
    xz
    unzip
    p7zip

    ripgrep
    ast-grep
    jq
    yq-go
    eza
    fzf
    fd
    serpl
    xclip
    wl-clipboard
    xsel

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
    imagemagick
    resvg
    poppler
    ffmpeg
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

    gcc
    gdb
    valgrind
    zig
    nim-unwrapped

    localsend
    vscode
    telegram-desktop
    qq
    wechat
    motrix
  ];

  programs.helix = {
    enable = true;
    # defaultEditor = true;
  };
  xdg.configFile."helix" = {
    source = ./assets/helix;
    recursive = true;
    executable = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
  };
  xdg.configFile."nvim" = {
    source = ./assets/nvim;
    recursive = true;
    executable = true;
  };

  programs.git = {
    enable = true;
    userName = "lantianx";
    userEmail = "lantianx233@gmail.com";
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
        email = "lantianx233@gmail.com";
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
  };
  xdg.configFile."starship.toml".source = ./assets/starship.toml;

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
