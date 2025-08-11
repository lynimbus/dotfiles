{
  config,
  pkgs,
  lib,
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

    localsend
    vscode
    zed-editor
    telegram-desktop
    qq
    motrix

    devenv
  ];

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

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
      devinit = {
        body = ''
          set env $argv[1]

          if test (count $argv) -ge 2
            set dir $argv[2]
          else
            set dir .
          end

          nix flake new --template "https://flakehub.com/f/the-nix-way/dev-templates/*#$env" $dir
          direnv allow $dir
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

  # https://wiki.archlinux.org.cn/title/Tencent_QQ#Empty_login_page_after_a_hot_update
  home.activation = {
    qqRollbackScript = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run ${pkgs.bash}/bin/bash ${builtins.toPath ./assets/QQ/qq-version-rollback.sh}
    '';
  };

  home.stateVersion = "25.05";
}
