{
  lib,
  stdenv,
  fetchurl,
  alsa-lib,
  asar,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  cairo,
  copyDesktopItems,
  cups,
  dbus,
  expat,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  jq,
  libGL,
  libgbm,
  libnotify,
  libpulseaudio,
  libsecret,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  makeDesktopItem,
  makeShellWrapper,
  nspr,
  nss,
  pango,
  pipewire,
  systemdLibs,
  wrapGAppsHook3,
  # Google addresses a release as `${version}-${buildId}`: the download
  # directory carries a build id that upstream renumbers on every upload, and
  # only the update manifest states it. So the two literals move together —
  # "just bump antigravity-hub" reads both out of that manifest and writes them
  # here, and the URL below only resolves once both are in place.
  #
  # nixpkgs carries this package too, but its release pin trails upstream's: on
  # 2026-11-16 nixpkgs still held 2.29.0 while the app was on 2.32.1, and the
  # bump for it was sitting unmerged in NixOS/nixpkgs#587894. overlay.nix
  # replaces the nixpkgs attribute in place.
  version ? "2.35.2",
  buildId ? "4585983447007232",
  hash ? "sha256-LTPbKCsemzx1gsFA2rnoaEjxs3oFv6Sh3/f0TeG/ME8=",
}:

stdenv.mkDerivation {
  pname = "antigravity-hub";
  inherit version;

  # Only the x86_64-linux asset is pinned. This flake builds one system, and a
  # bump rewrites the hash of the system it runs on; pinning the other assets
  # would leave their hashes silently stale instead of failing to evaluate.
  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-hub/${version}-${buildId}/linux-x64/Antigravity.tar.gz";
    inherit hash;
  };

  __structuredAttrs = true;
  strictDeps = true;

  nativeBuildInputs = [
    asar
    autoPatchelfHook
    copyDesktopItems
    makeShellWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    glib
    gsettings-desktop-schemas
    gtk3
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    pango
    systemdLibs
  ];

  # Loaded with dlopen() by the main binary, so autoPatchelfHook cannot discover them.
  runtimeDependencies = map lib.getLib [
    libnotify
    libpulseaudio
    libsecret
    pipewire
  ];
  # The bundled ANGLE libraries (libEGL.so, libGLESv2.so) dlopen() the system GL
  # libraries. runtimeDependencies only applies to executables, so extend the
  # RUNPATH of every patched ELF file instead.
  appendRunpaths = [ "${lib.getLib libGL}/lib" ];

  # The wrapper is created in postFixup to add the Wayland flags.
  dontWrapGApps = true;

  desktopItems = [
    (makeDesktopItem {
      name = "antigravity-hub";
      desktopName = "Antigravity";
      comment = "Manage multiple autonomous agents across independent projects";
      exec = "antigravity %U";
      icon = "antigravity";
      categories = [ "Development" ];
      mimeTypes = [ "x-scheme-handler/antigravity" ];
      startupWMClass = "antigravity";
    })
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/antigravity
    cp -r . $out/share/antigravity

    asar extract-file resources/app.asar icon.png
    install -Dm644 icon.png $out/share/icons/hicolor/512x512/apps/antigravity.png

    runHook postInstall
  '';

  # wrapGAppsHook3 provides makeBinaryWrapper, which cannot expand the shell
  # variables in --add-flags, hence makeShellWrapper.
  postFixup = ''
    makeShellWrapper $out/share/antigravity/antigravity $out/bin/antigravity \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
  '';

  # versionCheckHook cannot be used here: the binary ignores --version and opens
  # a window instead. The bundle's own package.json is where the release states
  # its version, and it is the one thing a stale or mislabelled upload gets
  # wrong, so the check reads it out of app.asar. --build in passthru.bump is
  # what runs it as part of a bump rather than at switch time.
  doInstallCheck = true;
  nativeInstallCheckInputs = [ jq ];
  installCheckPhase = ''
    runHook preInstallCheck

    asar extract-file $out/share/antigravity/resources/app.asar package.json
    bundled="$(jq -r .version package.json)"
    if [ "$bundled" != "$version" ]; then
      echo "the upload is $bundled, not $version" >&2
      exit 1
    fi

    runHook postInstallCheck
  '';

  passthru = {
    # The literal the URL is built from, read back by scripts/bump-packages.sh so a
    # build id is never replaced by matching a number it guesses at.
    inherit buildId;

    # The manifest is Google's own: it states the version at the top and every
    # asset's URL, whose path segment is `${version}-${buildId}`. --build proves
    # the hash nix-update prefetched and the version the upload states.
    bump = [
      "--build"
      "--bump-app-manifest=https://antigravity-hub-auto-updater-974169037036.us-central1.run.app/manifest/latest-x64-linux.yml"
    ];
  };

  meta = {
    description = "Desktop environment for managing multiple autonomous agents across independent projects";
    homepage = "https://antigravity.google";
    changelog = "https://antigravity.google/changelog";
    downloadPage = "https://antigravity.google/download";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "antigravity";
  };
}
