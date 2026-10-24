{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  glib-networking,
  gtk3,
  patchelf,
  webkitgtk_4_1,
  wrapGAppsHook3,
  bun,
  rtk,
  versionCheckHook,
  xdg-utils,
  releaseLib,
  releaseManifest,
  upstream,
}:

let
  release = releaseLib.githubRelease {
    pname = "magpie";
    manifest = releaseManifest;
  };

  runtimeLibs = [
    gtk3
    webkitgtk_4_1
    # libsoup's HTTPS is the GIO TLS module; without it the window loads local
    # pages, then fails every remote image and request.
    glib-networking
  ];
in
stdenv.mkDerivation {
  pname = "magpie";
  inherit (release) version;

  src = fetchurl (release.asset "magpie-linux-amd64");

  nativeBuildInputs = [
    autoPatchelfHook
    copyDesktopItems
    patchelf
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibs;

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;

  # autoPatchelfHook sets the interpreter in one pass and the rpath in the next.
  # On this asset that order leaves .dynamic inside the read-only PT_LOAD and the
  # binary faults at load. Writing the rpath first grows the segments into a
  # layout that runs. The value itself is thrown away: the hook rewrites its own
  # from buildInputs, so ordering is all this buys. installCheck runs the binary,
  # so a patchelf change breaks the build instead of shipping it.
  preFixup = ''
    patchelf --set-rpath ${lib.makeLibraryPath runtimeLibs} $out/bin/magpie

    gappsWrapperArgs+=(
      --prefix PATH : ${
        lib.makeBinPath [
          rtk
          xdg-utils
        ]
      }
      --set MAGPIE_BUN ${lib.getExe bun}
    )
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "magpie";
      desktopName = "magpie";
      genericName = "Model picker";
      comment = "Every agent's model. One place.";
      exec = "magpie %u";
      icon = "magpie";
      categories = [
        "Development"
        "Utility"
      ];
      mimeTypes = [ "x-scheme-handler/magpie" ];
      startupWMClass = "magpie";
      terminal = false;
    })
  ];

  installPhase = ''
    runHook preInstall

    install -Dm755 $src $out/bin/magpie
    install -Dm644 ${upstream}/internal/gui/icon-256.png \
      $out/share/icons/hicolor/256x256/apps/magpie.png
    install -Dm644 ${upstream}/internal/gui/icon-1024.png \
      $out/share/icons/hicolor/1024x1024/apps/magpie.png
    install -Dm644 ${upstream}/build/icon/magpie.svg \
      $out/share/icons/hicolor/scalable/apps/magpie.svg
    install -Dm644 ${upstream}/LICENSE $out/share/licenses/magpie/LICENSE

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Local gateway that picks the model for each AI coding agent";
    homepage = "https://usemagpie.ai/";
    changelog = "https://github.com/yetone/magpie/releases/tag/v${release.version}";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
