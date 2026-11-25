{ pkgs, lib, ... }:

let
  # nix-init resolves builder arguments and prefetches hashes against a nixpkgs
  # it evaluates itself. Pin it to the revision this configuration is built with,
  # so a generated package names arguments that exist in the nixpkgs that will
  # actually build it instead of whatever the channel happens to hold.
  nixpkgs = "${pkgs.path}";
in
{
  home.packages = with pkgs; [
    # Everyday command line.
    neovim
    helix
    ripgrep
    jq
    just
    nvd
    gh
    jjui
    beads
    dolt
    obelisk-cli
    antigravity-cli
    herdr-core
    agent-purge
    # Claude Code in a container that mounts nothing but the directory it is
    # started in. The package supplies both names, `blackhole` and `claude`;
    # the engine it talks to is system/docker.nix.
    blackhole
    fd
    eza
    bat
    fastfetch
    dig
    # Network capture. tshark and dumpcap are one package (wireshark-cli), and
    # system/wireshark.nix installs it too for the setcap wrapper that lets the
    # wireshark group capture without root; naming it here as well is what puts
    # it in the login profile and on the overview page. termshark is the
    # terminal frontend for tshark, mitmproxy the HTTPS proxy for reading one
    # connection's requests instead of the whole interface.
    tshark
    termshark
    mitmproxy
    shellcheck
    libxml2
    file
    sing-box

    # Desktop programs.
    ddcutil
    wl-clipboard
    tmux
    adw-gtk3
    librewolf
    ungoogled-chromium
    ayugram-desktop
    wechat-uos
    file-roller
    kero
    alma
    mygo-music
    mayoi
    overview
    obs-studio
    antigravity-hub

    # Gaming launchers, compatibility layers, and diagnostics.
    heroic
    lutris
    protonplus
    mangohud
    umu-launcher
    wineWow64Packages.stagingFull
    winetricks
    vulkan-tools
    mesa-demos

    # Archives and conversion.
    zip
    unzip
    p7zip
    _7zz-rar
    unrar
    unar
    ouch-rar
    zstd
    xz
    ffmpeg
    imagemagick
    poppler

    # Development toolchain. nix-init and nix-update are what scripts/
    # scaffold-package.sh and scripts/bump-packages.sh drive, so they have to be on
    # PATH where those scripts run.
    nix-init
    nix-update
    nixfmt
    zig
    koka
    go
    mygo
    android-tools
    payload-dumper-go
    # Python with numpy/onnxruntime/pillow so the Noctalia widget-aware wallpaper
    # depth service (lynimbus/m3-expressive) runs ONNX inference natively on NixOS.
    (python3.withPackages (
      ps: with ps; [
        numpy
        onnxruntime
        pillow
      ]
    ))
    nodejs
    pnpm
    nil
    nixd
    # Rust: the toolchain nsh builds an app's runner with (the nsh launcher
    # falls back to this cargo when no rustup is on PATH), and rust-analyzer
    # for editing the app's own Rust code. rustup is the one toolchain that
    # can cross-compile for Android (nixpkgs' rustc ships no android std), so
    # `rustup default stable` plus `rustup target add aarch64-linux-android
    # armv7-linux-androideabi x86_64-linux-android` is the one manual step an
    # Android app with Rust code needs; it runs through nix-ld.
    rustc
    cargo
    clippy
    rustfmt
    rust-analyzer
    # rustup also ships bin/cargo, bin/rustc, and zsh _cargo completion, which
    # collide with nixpkgs's toolchain in buildEnv (rustc already has priority
    # 10, so lowPrio's 10 still collides). Priority 20 keeps nixpkgs cargo/rustc
    # working until a rustup toolchain is configured while putting `rustup` on PATH.
    (lib.setPrio 20 rustup)
    sccache
    mold
    # nsh (Native Shell): the TSX-on-native-runtime GUI framework. The package
    # keeps a writable copy of its distribution in ~/.nsh and downloads the
    # web and Android runtimes there on first use; home/programs/nsh.nix sets
    # the Android SDK it packages against.
    nsh
    # Java: the Eclipse JDT language server (nixpkgs wraps it with its own JDK,
    # so jdtls runs standalone and pi-lens stops reporting "java analysis
    # unavailable") plus a plain JDK 17 for javac/java work and the r8 wrapper
    # below.
    jdt-language-server
    openjdk17
    # Diagnostic runners pi-lens resolves from PATH. With opengrep found there
    # the lens never falls back to its own installer, which would fetch the
    # GitHub binary unpatched for NixOS.
    ast-grep
    typos
    opengrep
    # Reverse-engineering toolchain for shipped Android artefacts: ELF
    # inspection, dex/apk decompiling, and the EROFS images modern Android ships
    # its system partitions in.
    binutils
    llvm
    jadx
    apktool
    erofs-utils
    # d8/r8 dexer from Google Maven (overlay): the one piece of the Android build
    # chain nixpkgs does not carry, so Java can be compiled to dex instead of
    # hand-writing smali.
    r8
  ];

  xdg.configFile."nix-init/config.toml".text = ''
    nixpkgs = '${nixpkgs}'

    # Nothing here lives in a nixpkgs by-name tree, and this repository is
    # driven by jj, so nix-init must never commit on its own.
    commit = false

    # nix-init only detects nixfmt if it is on PATH; name it explicitly. The
    # bare form warns that it will stop reading stdin anonymously, so say "-".
    [format]
    command = ["nixfmt", "-"]

    # Every run asks the GitHub API for the description, the releases, the tags
    # and the recent commits, and the anonymous quota is 60 an hour per IP. gh
    # already holds a token in the keyring, so read it from there instead of
    # keeping a secret in this repository.
    [access-tokens]
    "github.com".command = ["gh", "auth", "token"]
  '';
}
