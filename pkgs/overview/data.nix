# The data behind the overview desktop app: what this flake installs and how it
# is configured, read out of the evaluated configuration rather than restated by
# hand. The app evaluates this file directly on launch and on Refresh.
#
# Packages come from the derivations themselves and the settings come from the
# home-manager module system, so a package added to packages.nix or a setting
# changed in a program module reaches the page on the next build without the
# page being edited.
let
  flake = builtins.getFlake (toString ../..);
  repoSrc = toString flake;
  hostName = builtins.head (builtins.attrNames flake.nixosConfigurations);
  nixos = flake.nixosConfigurations.${hostName};
  system = nixos.pkgs.stdenv.hostPlatform.system;
  pkgs = flake.legacyPackages.${system};
  systemConfig = nixos.config;
  userName = builtins.head (builtins.attrNames systemConfig.home-manager.users);
  home = systemConfig.home-manager.users.${userName};

  hasPrefix =
    prefix: str:
    builtins.stringLength str >= builtins.stringLength prefix
    && builtins.substring 0 (builtins.stringLength prefix) str == prefix;

  # Local derivations are detected directly from their definition path inside
  # this flake (covering pkgs/* and inline home/ derivations like memo or
  # hy-mt2-server), with bumpMatrix pnames as a fallback if position is absent.
  localBumpPnames = map (name: pkgs.${name}.pname or pkgs.${name}.name or name) (
    builtins.attrNames pkgs.bumpMatrix
  );

  isLocalDrv =
    drv:
    let
      pos = (drv.meta or { }).position or "";
      pname = drv.pname or drv.name or "";
    in
    (pos != "" && hasPrefix repoSrc pos) || builtins.elem pname localBumpPnames;

  # home-manager's own build-time scaffolding lands in home.packages too
  # (session variables, a manpage, empty MIME and font directories). None of it
  # is a program the user starts, so the page does not show it.
  isInternal =
    pname: builtins.match "(dummy-.*|hm-session-vars.*|home-configuration-.*)" pname != null;

  sectionOrder = [
    "desktop"
    "local"
    "cli"
    "libs"
  ];

  sectionLabels = {
    desktop = "Desktop apps";
    local = "Built in this repo";
    cli = "CLI & toolchain";
    libs = "Libraries & assets";
  };

  # Classify every package from its derivation output and repo origin alone, so
  # adding or removing packages never requires maintaining a manual list here.
  sectionFor =
    drv:
    let
      out = if drv.outPath or null == null then null else drv.outPath;
      appsDir = if out == null then null else out + "/share/applications";
      hasApps = appsDir != null && builtins.pathExists appsDir;
      desktopFiles =
        if hasApps then
          builtins.filter (f: builtins.match ".*\\.desktop" f != null) (
            builtins.attrNames (builtins.readDir appsDir)
          )
        else
          [ ];
      isTermDesktop =
        f: builtins.match ".*Terminal=true.*" (builtins.readFile (appsDir + "/" + f)) != null;
      isGuiApp = desktopFiles != [ ] && !(builtins.all isTermDesktop desktopFiles);
      isWaylandSession = out != null && builtins.pathExists (out + "/share/wayland-sessions");
      hasBin = out != null && builtins.pathExists (out + "/bin");
    in
    if isGuiApp || isWaylandSession then
      "desktop"
    else if isLocalDrv drv then
      "local"
    else if hasBin then
      "cli"
    else
      "libs";

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
      local = isLocalDrv drv;
      section = sectionFor drv;
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
    }) sectionOrder
  );
in
{
  meta = {
    hostname = hostName;
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
        name = "umbriel";
        enable = home.programs.umbriel.enable;
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
