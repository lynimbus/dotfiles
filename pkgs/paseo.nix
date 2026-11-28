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
  cups,
  dbus,
  dpkg,
  expat,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  jq,
  libGL,
  libayatana-appindicator,
  libgbm,
  libnotify,
  libpulseaudio,
  libsecret,
  libuv,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  makeShellWrapper,
  nspr,
  nss,
  pango,
  pipewire,
  systemdLibs,
  wrapGAppsHook3,
  # The GitHub release .deb bundles the prebuilt Electron desktop app, daemon,
  # web UI, and `resources/bin/paseo` CLI together (with upstream's postinstall
  # patches already applied), avoiding the ~13-minute local npm/Expo rebuild.
  version ? "0.18.1",
  hash ? "sha256-rClpDX+yt/IcS/zvq1tTQxdUKUj9iLKg2DN6ocjB7XU=",
}:

stdenv.mkDerivation {
  pname = "paseo";
  inherit version;

  src = fetchurl {
    url = "https://github.com/getpaseo/paseo/releases/download/v${version}/Paseo-${version}-amd64.deb";
    inherit hash;
  };

  __structuredAttrs = true;
  strictDeps = true;

  nativeBuildInputs = [
    asar
    autoPatchelfHook
    dpkg
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
    libuv
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
    stdenv.cc.cc.lib
    systemdLibs
  ];

  # Loaded with dlopen() by Electron or tray/notification helpers.
  runtimeDependencies = map lib.getLib [
    libayatana-appindicator
    libnotify
    libpulseaudio
    libsecret
    pipewire
  ];

  # Bundled ANGLE / Vulkan libraries dlopen() system GL libraries.
  appendRunpaths = [ "${lib.getLib libGL}/lib" ];

  # The wrapper is created in postFixup to add the Wayland and sandbox flags.
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/share/paseo" "$out/share/applications" "$out/share/icons/hicolor/512x512/apps"
    cp -r opt/Paseo/. "$out/share/paseo/"
    cp -r usr/share/icons/hicolor/. "$out/share/icons/hicolor/"
    install -Dm644 opt/Paseo/resources/icon.png "$out/share/icons/hicolor/512x512/apps/Paseo.png"

    # Nix manages upgrades; drop the Electron updater manifest and musl prebuilds
    # that autoPatchelfHook cannot resolve on glibc.
    rm -f "$out/share/paseo/resources/app-update.yml"
    find "$out/share/paseo" -name '*.musl.node' -delete

    install -Dm644 usr/share/applications/Paseo.desktop "$out/share/applications/Paseo.desktop"
    substituteInPlace "$out/share/applications/Paseo.desktop" \
      --replace-fail "/opt/Paseo/Paseo" "paseo-desktop"

    # Expose upstream's bundled CLI launcher (resolves symlinks back to Paseo.bin).
    ln -s ../share/paseo/resources/bin/paseo "$out/bin/paseo"

    runHook postInstall
  '';

  postFixup = ''
    makeShellWrapper "$out/share/paseo/Paseo.bin" "$out/bin/paseo-desktop" \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "--no-sandbox" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ jq ];
  installCheckPhase = ''
    runHook preInstallCheck

    asar extract-file "$out/share/paseo/resources/app.asar" package.json
    bundled="$(jq -r .version package.json)"
    if [ "$bundled" != "$version" ]; then
      echo "the upload is $bundled, not $version" >&2
      exit 1
    fi

    HOME="$TMPDIR" "$out/bin/paseo" --version

    runHook postInstallCheck
  '';

  passthru.bump = [ "--build" ];

  meta = {
    description = "Self-hosted daemon and desktop app for AI coding agents";
    homepage = "https://paseo.sh";
    downloadPage = "https://github.com/getpaseo/paseo/releases";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "paseo";
  };
}
