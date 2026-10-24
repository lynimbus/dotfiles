{
  lib,
  stdenv,
  autoPatchelfHook,
  fetchurl,
  wrapGAppsHook3,
  gdk-pixbuf,
  glib,
  gsettings-desktop-schemas,
  gtk3,
  libsoup_3,
  webkitgtk_4_1,
  releaseLib,
  releaseManifest,
  rtk,
}:

let
  release = releaseLib.githubRelease {
    pname = "pi-agent-desktop";
    manifest = releaseManifest;
  };

  asset = release.asset "Pi.Agent_${release.version}_amd64.deb";

  version = release.version;
in
stdenv.mkDerivation {
  pname = "pi-agent-desktop";
  inherit version;

  src = fetchurl {
    inherit (asset) url hash;
  };

  nativeBuildInputs = [
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    gdk-pixbuf
    glib
    gsettings-desktop-schemas
    gtk3
    libsoup_3
    webkitgtk_4_1
    stdenv.cc.cc.lib
  ];

  unpackPhase = ''
    runHook preUnpack
    ar x $src
    tar -xf data.tar.*
    runHook postUnpack
  '';

  dontConfigure = true;
  dontBuild = true;

  patchelfFlags = [ "--no-sort" ];

  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath [ rtk ]}
      --prefix NODE_OPTIONS " " --use-openssl-ca
      --set-default SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt
    )
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/share $out/bin
    cp -r "usr/lib/Pi Agent" $out/lib/Pi\ Agent
    cp -r usr/share/applications usr/share/icons $out/share/
    install -Dm755 usr/bin/pi-agent-desktop $out/bin/pi-agent-desktop

    rm -rf $out/lib/Pi\ Agent/resources/server/node_modules/@img/sharp-linuxmusl-x64 \
           $out/lib/Pi\ Agent/resources/server/node_modules/@img/sharp-libvips-linuxmusl-x64

    runHook postInstall
  '';

  meta = {
    description = "Desktop UI for the pi coding agent";
    homepage = "https://github.com/abcwyc/pi-agent-desktop";
    license = lib.licenses.mit;
    mainProgram = "pi-agent-desktop";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
