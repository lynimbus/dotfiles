{
  lib,
  repoRoot,
  buildMyGoApp,
  makeDesktopItem,
  copyDesktopItems,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  harfbuzz,
  hicolor-icon-theme,
  libepoxy,
  libglvnd,
  libx11,
  libxtst,
  pango,
  shared-mime-info,
  wayland,
}:

let
  version = "0.1.0";

  runtimeLibs = map lib.getLib [
    at-spi2-atk
    at-spi2-core
    cairo
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    harfbuzz
    hicolor-icon-theme
    libepoxy
    libglvnd
    libx11
    libxtst
    pango
    shared-mime-info
    wayland
  ];

  src = lib.fileset.toSource {
    root = ./overview;
    fileset = lib.fileset.unions [
      ./overview/go.mod
      ./overview/go.sum
      ./overview/snapshot.json
      ./overview/icon.svg
      ./overview/i18n
      (lib.fileset.fileFilter (file: file.hasExt "go") ./overview)
    ];
  };
in
buildMyGoApp {
  pname = "overview";
  inherit
    version
    src
    runtimeLibs
    ;
  vendorHash = "sha256-TNAiiIsSkFQGvPr8d2lLVALjWrzS0ElRcgo2rl4zwMU=";
  packageName = "Overview";
  packageIdentifier = "dev.lynimbus.overview";
  extraLdflags = [
    "-X main.appVersion=${version}"
    "-X main.defaultRepoRoot=${repoRoot}"
  ];
  extraNativeBuildInputs = [ copyDesktopItems ];

  # Headless ui.NewTester unit tests run with real Pango/Cairo text shaping
  # during the build so layout and overflow regressions are caught immediately.
  doCheck = true;
  preCheck = ''
    export LD_LIBRARY_PATH="${lib.makeLibraryPath runtimeLibs}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
    export FONTCONFIG_FILE="${fontconfig.out}/etc/fonts/fonts.conf"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export XDG_CONFIG_HOME="$TMPDIR/config"
    mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME"
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "overview";
      desktopName = "Overview";
      genericName = "NixOS Flake Overview";
      comment = "Inspect what this NixOS flake installs and configures";
      exec = "overview";
      icon = "overview";
      terminal = false;
      categories = [
        "System"
        "Settings"
        "Utility"
      ];
    })
  ];

  postInstall = ''
    mkdir -p $out/lib/overview
    mv $out/bin/overview $out/lib/overview/overview
    install -Dm644 ${src}/icon.svg $out/share/icons/hicolor/scalable/apps/overview.svg
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    ver=$($out/bin/overview --version)
    case "$ver" in
      "overview ${version}") ;;
      *)
        echo "unexpected --version output: $ver" >&2
        exit 1
        ;;
    esac

    output=$(env -u DISPLAY -u WAYLAND_DISPLAY $out/bin/overview 2>&1 || true)
    case "$output" in
      *"cannot open display"*) ;;
      *)
        echo "overview did not initialize GTK as expected: $output" >&2
        exit 1
        ;;
    esac

    runHook postInstallCheck
  '';

  meta = {
    description = "Native MyGo desktop app that inspects what this NixOS flake installs and configures";
    license = lib.licenses.mit;
    mainProgram = "overview";
    platforms = [ "x86_64-linux" ];
  };
}
