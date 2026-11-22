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
  # The release asset and the four files upstream keeps in the source tree
  # rather than in it. docs/bump-packages.sh reads the release feed and hands
  # every literal here its new value in one run, so no release has a version or
  # a hash that can drift from the others.
  version ? "0.1.4670",
  hash ? "sha256-A5Yl498MgST+pC9mbM646ZmpFTPQ402fKJ1KColerO8=",
  icon256Hash ? "sha256-V0N8ZZbgWo/PxC1CiMAwqgDthraf411GTWnXAmFQxwQ=",
  icon1024Hash ? "sha256-SdkOjSz4AFXXjmLCQj9BRo6r82SRBLBsJLleR1yFDUc=",
  iconSvgHash ? "sha256-fT50MnUFiN0JxQqsNMF2NWQExwhiJmb8WYPxFR4mv/U=",
  licenseHash ? "sha256-edLIREcV1LxFPsT4oKryBRpMHuWsCPW9LlhIrvh8dXI=",
}:

let
  # fetchFromGitHub downloads the whole tree — 89MB of Go source — to reach four
  # files that add up to 45KB, and puts ~85s and one more failure into every
  # bump. raw.githubusercontent.com serves those files at the tag instead. They
  # were byte-identical across every release measured (300 of them, v0.1.3631 to
  # v0.1.3930), so their hashes move far less often than the version does; the
  # bump re-reads them anyway, in case upstream redraws an icon.
  treeFile =
    name: hash:
    fetchurl {
      url = "https://raw.githubusercontent.com/yetone/magpie/v${version}/${name}";
      inherit hash;
    };

  license = treeFile "LICENSE" licenseHash;
  icon256 = treeFile "internal/gui/icon-256.png" icon256Hash;
  icon1024 = treeFile "internal/gui/icon-1024.png" icon1024Hash;
  iconSvg = treeFile "build/icon/magpie.svg" iconSvgHash;

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
    install -Dm644 ${license} $out/share/licenses/magpie/LICENSE
    install -Dm644 ${icon256} $out/share/icons/hicolor/256x256/apps/magpie.png
    install -Dm644 ${icon1024} $out/share/icons/hicolor/1024x1024/apps/magpie.png
    install -Dm644 ${iconSvg} $out/share/icons/hicolor/scalable/apps/magpie.svg

    runHook postInstall
  '';

  # nix-update's --custom-dep takes a flat attribute path and prefetches
  # ${drv}.${name}.outputHash, so the four tree files have to be attributes of
  # the derivation. installPhase reads the let-bindings above, not these.
  inherit
    icon256
    icon1024
    iconSvg
    license
    ;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    # The feed carries the release's version and every asset's SHA-256 in one
    # answer, and signs the release's SHA256SUMS from 0.1.3862 on. Reading it
    # drops both of this package's old bump costs: the 89MB tree (gone with
    # fetchFromGitHub above) and the 82MB asset that nix-update prefetched to
    # re-derive a hash the feed already states.
    #
    # --no-src is what stops that prefetch; docs/bump-packages.sh writes src's
    # hash from the feed instead. The tree files still go through nix-update,
    # which prefetches each of them: 45KB in total.
    bump = [
      "--no-src"
      "--bump-feed=https://usemagpie.ai/api/latest"
      "--bump-asset=magpie-linux-amd64"
      "--custom-dep"
      "icon256"
      "--custom-dep"
      "icon1024"
      "--custom-dep"
      "iconSvg"
      "--custom-dep"
      "license"
    ];
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
