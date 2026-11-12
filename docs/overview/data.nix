# The data behind docs/overview.html: what this flake installs and how it is
# configured, read out of the evaluated configuration rather than restated by
# hand. docs/overview/build.sh renders it into the page.
#
# Packages come from the derivations themselves and the settings come from the
# home-manager module system, so a package added to packages.nix or a setting
# changed in a program module reaches the page on the next build without the
# page being edited.
let
  flake = builtins.getFlake (toString ../..);
  # The system the configuration builds for, read from the configuration rather
  # than repeated here, so a second host or an arch change does not need an edit.
  system = flake.nixosConfigurations.nixos.pkgs.stdenv.hostPlatform.system;
  pkgs = flake.legacyPackages.${system};
  home = flake.nixosConfigurations.nixos.config.home-manager.users.lynimbus;
  systemConfig = flake.nixosConfigurations.nixos.config;

  # overlay.nix derives this list from pkgs/ and hangs it off bumpMatrix, so the
  # page can tell the packages this repo builds from the ones nixpkgs does.
  localNames = builtins.attrNames pkgs.bumpMatrix;

  # sectionOf is the page's own taxonomy, not a second copy of packages.nix:
  # it only decides which shelf a package sits on. Anything unlisted lands in
  # "Other", so a new package still shows up without an edit here.
  # These lists hold pnames, which is not always the attribute name packages.nix
  # writes: dig arrives as bind, shellcheck as ShellCheck, poppler as
  # poppler-glib, mango-nightly as mango.
  sectionOf = {
    daily = [
      "neovim"
      "helix"
      "ripgrep"
      "fzf"
      "jq"
      "just"
      "nvd"
      "gh"
      "jjui"
      "beads"
      "dolt"
      "obelisk-cli"
      "antigravity-cli"
      "fd"
      "eza"
      "bat"
      "fastfetch"
      "bind"
      "ShellCheck"
      "libxml2"
      "file"
      "sing-box"
    ];
    desktop = [
      "ddcutil"
      "wlsunset"
      "wl-clipboard"
      "tmux"
      "xwayland-satellite"
      "librewolf"
      "ungoogled-chromium"
      "ayugram-desktop"
      "wechat-uos"
      "strata"
      "kero"
      "mygo-music"
      "mayoi"
      "obs-studio"
      "ghostty"
      "mango"
      "shared-mime-info"
      "kbd-backlight"
      "screenshot"
      "memo"
      "noctalia"
    ];
    network = [
      "wireshark-cli"
      "termshark"
      "mitmproxy"
    ];
    media = [
      "zip"
      "unzip"
      "p7zip"
      "xz"
      "ffmpeg"
      "imagemagick"
      "poppler-glib"
    ];
    dev = [
      "nix-init"
      "nix-update"
      "nixfmt"
      "zig"
      "koka"
      "go"
      "mygo"
      "android-tools"
      "payload-dumper-go"
      "python3"
      "nodejs"
      "nil"
      "nixd"
      "jdt-language-server"
      "openjdk"
      "ast-grep"
      "typos"
      "opengrep"
      "binutils-wrapper"
      "llvm"
      "jadx"
      "apktool"
      "erofs-utils"
      "r8"
    ];
    tooling = [
      "git"
      "fish"
      "direnv"
      "jujutsu"
      "zoxide"
      "meld"
      "difftastic"
      "delta"
      "man-db"
      "man"
      "zstd"
    ];
    agents = [
      "magpie"
      "pig"
      "pig-swarm"
      "kero"
      "alma"
      "antigravity-cli"
      "rtk"
    ];
  };

  # home-manager's own build-time scaffolding lands in home.packages too
  # (session variables, a manpage, empty MIME and font directories). None of it
  # is a program the user starts, so the page does not show it.
  isInternal =
    pname: builtins.match "(dummy-.*|hm-session-vars.*|home-configuration-.*)" pname != null;

  sectionLabels = {
    daily = "Everyday command line";
    desktop = "Desktop";
    network = "Network capture";
    media = "Archives and conversion";
    dev = "Development toolchain";
    agents = "Coding agents";
    tooling = "Managed by a module";
    other = "Other";
  };

  sectionFor =
    pname:
    let
      hits = builtins.filter (key: builtins.elem pname sectionOf.${key}) (builtins.attrNames sectionOf);
    in
    if hits == [ ] then "other" else builtins.head hits;

  # The icon a desktop package ships, if it ships one. Read from the store the
  # derivation points at, so it is the same icon the launcher shows.
  iconCandidates = [
    "256x256/apps"
    "512x512/apps"
    "scalable/apps"
    "128x128/apps"
  ];

  findIcon =
    drv:
    let
      out = if drv.outPath or null == null then null else drv.outPath;
      probe =
        dir:
        let
          full = out + "/share/icons/hicolor/" + dir;
        in
        if builtins.pathExists full then
          map (name: {
            path = full + "/" + name;
            svg = builtins.match ".*\\.svg" name != null;
          }) (builtins.attrNames (builtins.readDir full))
        else
          [ ];
    in
    if out == null then
      null
    else
      let
        found = builtins.concatMap probe iconCandidates;
      in
      if found == [ ] then null else (builtins.head found).path;

  pkgInfo =
    drv:
    let
      pname = drv.pname or drv.name or "unknown";
      meta = drv.meta or { };
      licences =
        if meta.license or null == null then
          [ ]
        else if builtins.isList meta.license then
          map (l: l.shortName or l.spdxId or "unknown") meta.license
        else
          [ (meta.license.shortName or meta.license.spdxId or "unknown") ];
    in
    {
      inherit pname;
      version = drv.version or null;
      description = meta.description or null;
      homepage = meta.homepage or null;
      license = licences;
      local = builtins.elem pname localNames;
      section = sectionFor pname;
      icon = findIcon drv;
    };

  # A package is reachable from more than one module (fish arrives with zoxide
  # and with home-manager's own list), and the page shows one card per app.
  dedupe =
    list:
    builtins.foldl' (
      acc: item: if builtins.any (seen: seen.pname == item.pname) acc then acc else acc ++ [ item ]
    ) [ ] list;

  flatten = groups: builtins.concatMap (group: group.items) groups;

  packages = builtins.filter (p: !isInternal p.pname) (dedupe (map pkgInfo home.home.packages));

  sections = builtins.filter (s: s.items != [ ]) (
    map (key: {
      id = key;
      label = sectionLabels.${key};
      items = builtins.filter (p: p.section == key) packages;
    }) (builtins.attrNames sectionLabels)
  );
in
{
  meta = {
    hostname = "nixos";
    inherit system;
    stateVersion = systemConfig.system.stateVersion;
    nixpkgsRev = flake.inputs.nixpkgs.shortRev or "unknown";
    homeManagerRev = flake.inputs.home-manager.shortRev or "unknown";
    packageCount = builtins.length packages;
    localCount = builtins.length (builtins.filter (p: p.local) packages);
  };

  inherit sections;
  total = builtins.length (flatten sections);

  programs = {
    fish = {
      enable = home.programs.fish.enable;
      aliases = home.programs.fish.shellAliases;
      # The module's own script verbatim. A summary sentence here would be prose
      # the page cannot translate, and a summary of the truth is still a second
      # copy of it; the page trims the indentation and shows the lines.
      interactiveShellInit = home.programs.fish.interactiveShellInit;
    };
    git = {
      enable = home.programs.git.enable;
      settings = home.programs.git.settings;
    };
    jujutsu = {
      enable = home.programs.jujutsu.enable;
      settings = home.programs.jujutsu.settings;
    };
    ssh = {
      enable = home.programs.ssh.enable;
      hosts = builtins.attrNames home.programs.ssh.settings;
    };
    ghostty = {
      enable = home.programs.ghostty.enable;
      settings = home.programs.ghostty.settings;
    };
    zoxide = {
      enable = home.programs.zoxide.enable;
      options = home.programs.zoxide.options;
    };
    direnv = {
      enable = home.programs.direnv.enable;
      nixDirenv = home.programs.direnv.nix-direnv.enable;
    };
  };

  desktop = {
    windowManagers = [
      # mode is a token, not a phrase: the page words it in whichever language is
      # selected, so no English leaks into the data.
      {
        name = "niri";
        enable = true;
        mode = "scrollable";
      }
      {
        name = "mango";
        enable = home.wayland.windowManager.mango.enable;
        mode = "dwindle";
      }
    ];
    shell = "noctalia";
    sessionVariables = home.home.sessionVariables;
    userServices = builtins.attrNames home.systemd.user.services;
    userTimers = builtins.attrNames home.systemd.user.timers;
    inputMethod = "fcitx5";
    fonts = [
      "Noto Sans / CJK / Color Emoji"
      "JetBrainsMono Nerd Font"
      "Maple Mono NF CN"
      "Fira Code"
      "Intel One Mono"
      "Intone Mono"
    ];
  };

  toolchain = {
    go = pkgs.go.version;
    node = pkgs.nodejs.version;
    python = pkgs.python3.version;
    zig = pkgs.zig.version;
    java = pkgs.openjdk17.version;
    koka = pkgs.koka.version;
    nixfmt = pkgs.nixfmt.version;
  };
}
