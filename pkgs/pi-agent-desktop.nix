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
  releaseManifest,
  rtk,
}:

let
  release = builtins.fromJSON (builtins.readFile releaseManifest);

  version = lib.removePrefix "v" release.tag_name;

  releaseAsset = lib.findFirst (
    asset: asset.name == "Pi.Agent_${version}_amd64.deb"
  ) (throw "pi-agent-desktop: release ${version} has no amd64 deb asset") release.assets;
in
stdenv.mkDerivation {
  pname = "pi-agent-desktop";
  inherit version;

  src = fetchurl {
    url = releaseAsset.browser_download_url;
    hash = builtins.convertHash {
      hash = lib.removePrefix "sha256:" releaseAsset.digest;
      hashAlgo = "sha256";
      toHashFormat = "sri";
    };
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

  preFixup = ''
    gappsWrapperArgs+=(--prefix PATH : ${lib.makeBinPath [ rtk ]})
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
