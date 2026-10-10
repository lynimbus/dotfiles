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
  fetchFromGitHub,
  # The icons and the licence are files of the source tree, not of the
  # release archive: the tagged tree is a fetchFromGitHub of its own beside
  # the binary, and `just bump magpie` (nix-update) moves the version, the
  # asset hash and the tree hash in lockstep (`--custom-dep upstream`
  # handles the tree).
  version ? "0.1.2433",
  hash ? "sha256-aU9RS3m+SVupChR4PnyYI80oWkIkIfs3y5bU0766hQE=",
  upstreamHash ? "sha256-sn3M5FMVXHFKkabP6t43P8frdZ9XBkPBaeUZBPHdxxc=",
}:

let
  # The source tree of the same tag the binary release names.
  upstream = fetchFromGitHub {
    owner = "yetone";
    repo = "magpie";
    tag = "v${version}";
    hash = upstreamHash;
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
  inherit version;

  src = fetchurl {
    url = "https://github.com/yetone/magpie/releases/download/v${version}/magpie-linux-amd64";
    inherit hash;
  };

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
      --set-default MAGPIE_NO_STATS 1
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

  passthru = {
    # nix-update's --custom-dep upstream rewrites the tree hash beside the
    # asset hash in the same file, so one bump moves the whole release.
    inherit upstream;
  };

  meta = {
    description = "Local gateway that picks the model for each AI coding agent";
    homepage = "https://usemagpie.ai/";
    changelog = "https://github.com/yetone/magpie/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
