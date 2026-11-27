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
  version ? "0.1.29927281",
  hash ? "sha256-inNuQ90hCnvjyKQAvNInRcMIbcXNmuY+PiqQmc1tJ48=",
}:

stdenv.mkDerivation {
  pname = "amp-desktop";
  inherit version;

  src = fetchurl {
    url = "https://static.ampcode.com/linux/${version}/amp-desktop-${version}-amd64.deb";
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

  # The wrapper is created in postFixup to add the Wayland flags.
  dontWrapGApps = true;

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/amp-desktop" "$out/share/applications" "$out/share/icons"
    cp -r opt/amp/. "$out/share/amp-desktop/"
    cp -r usr/share/icons/hicolor "$out/share/icons/"

    install -Dm644 usr/share/applications/amp-desktop.desktop "$out/share/applications/amp-desktop.desktop"
    substituteInPlace "$out/share/applications/amp-desktop.desktop" \
      --replace-fail "/opt/amp/amp-desktop" "amp-desktop"

    runHook postInstall
  '';

  postFixup = ''
    makeShellWrapper "$out/share/amp-desktop/amp-desktop" "$out/bin/amp-desktop" \
      "''${gappsWrapperArgs[@]}" \
      --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+--ozone-platform-hint=auto --enable-features=WaylandWindowDecorations}}"
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ jq ];
  installCheckPhase = ''
    runHook preInstallCheck

    asar extract-file "$out/share/amp-desktop/resources/app.asar" package.json
    bundled="$(jq -r .version package.json)"
    if [ "$bundled" != "$version" ]; then
      echo "the upload is $bundled, not $version" >&2
      exit 1
    fi

    runHook postInstallCheck
  '';

  meta = {
    description = "Native desktop GUI application for Amp, the agentic coding agent";
    homepage = "https://ampcode.com/";
    downloadPage = "https://ampcode.com/install";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "amp-desktop";
  };
}
