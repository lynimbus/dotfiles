{
  lib,
  stdenv,
  fetchurl,
  asar,
  autoPatchelfHook,
  dpkg,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  bubblewrap,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  glib-networking,
  gsettings-desktop-schemas,
  gtk3,
  libappindicator-gtk3,
  libdrm,
  libgbm,
  libGL,
  libnotify,
  libpulseaudio,
  libsecret,
  libuuid,
  # 0.2.x bundles a whole python 3.12 runtime in primary-runtime; its _crypt
  # module is the only extra library the deb does not carry itself.
  libxcrypt,
  libxkbcommon,
  libxscrnsaver,
  libxtst,
  nspr,
  nss,
  pango,
  patchelf,
  systemd,
  vips,
  vulkan-loader,
  # The release deb is the only source: `just bump deepseek-bot`
  # (nix-update) moves the version and its hash to the latest release
  # together.
  version ? "0.2.4",
  hash ? "sha256-DmQGGHtYJOtNXZIWtEJi5nTCxNMfNYszYi7BlQKtMYw=",
}:

stdenv.mkDerivation {
  pname = "deepseek-bot";
  inherit version;

  src = fetchurl {
    url = "https://github.com/Fei2411/DS-Bot/releases/download/v${version}/DeepSeek-Bot-${version}-linux-amd64.deb";
    inherit hash;
  };

  nativeBuildInputs = [
    asar
    autoPatchelfHook
    dpkg
    patchelf
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    glib-networking
    gsettings-desktop-schemas
    gtk3
    libxcrypt
    libappindicator-gtk3
    libdrm
    libgbm
    libGL
    libnotify
    libpulseaudio
    libsecret
    libuuid
    libxkbcommon
    libxscrnsaver
    libxtst
    nspr
    nss
    pango
    stdenv.cc.cc.lib
    systemd
    vips
    vulkan-loader
  ];

  unpackPhase = ''
    runHook preUnpack

    dpkg-deb --extract $src .

    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  runtimeDependencies = [
    libGL
    vulkan-loader
  ];

  preFixup = ''
    patchelf --replace-needed libvips-cpp.so.8.18.7 libvips-cpp.so.42 \
      "$out/lib/DeepSeek Bot/resources/app.asar.unpacked/node_modules/@img/sharp-linux-x64/lib"/*.node

    # 0.2.x bundles a python runtime whose _crypt module is linked against
    # glibc's old libcrypt.so.1; nixpkgs' libxcrypt ships the same crypt
    # entry points under its own libcrypt.so.2 soname, so the need is
    # redirected and autoPatchelf then finds the library in buildInputs.
    patchelf --replace-needed libcrypt.so.1 libcrypt.so.2 \
      "$out/lib/DeepSeek Bot/resources/primary-runtime/dependencies/python/lib/"python*/lib-dynload/_crypt*.so

    gappsWrapperArgs+=(
      --prefix NODE_OPTIONS " " --use-openssl-ca
      --set-default SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt
    )

    gappsWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath [ bubblewrap ]}
    )
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/share $out/bin
    cp -r "opt/DeepSeek Bot" "$out/lib/DeepSeek Bot"
    cp -r usr/share/applications usr/share/icons $out/share/
    ln -s "$out/lib/DeepSeek Bot/deepseek-bot" $out/bin/deepseek-bot

    substituteInPlace $out/share/applications/deepseek-bot.desktop \
      --replace-fail '"/opt/DeepSeek Bot/deepseek-bot"' "$out/bin/deepseek-bot"

    asar extract-file "$out/lib/DeepSeek Bot/resources/app.asar" assets/icon.svg
    install -Dm644 icon.svg "$out/share/icons/hicolor/scalable/apps/deepseek-bot.svg"
    rm icon.svg

    rm -rf "$out/lib/DeepSeek Bot/resources/app.asar.unpacked/node_modules/node-pty/prebuilds"/{darwin-arm64,darwin-x64,win32-arm64,win32-x64}
    rm -rf "$out/lib/DeepSeek Bot/resources/app.asar.unpacked/node_modules/@koromix/koffi-linux-x64/musl_x64"

    runHook postInstall
  '';

  meta = {
    description = "DeepSeek Bot desktop app: the ds-bot team on its own pinned DeepSeek Harness";
    homepage = "https://github.com/Fei2411/DeepSeek-Bot";
    changelog = "https://github.com/Fei2411/DeepSeek-Bot/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "deepseek-bot";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
