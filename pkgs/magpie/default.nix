{
  lib,
  buildGoModule,
  bun,
  copyDesktopItems,
  glib-networking,
  gtk3,
  makeDesktopItem,
  pkg-config,
  releaseManifest,
  src,
  versionCheckHook,
  webkitgtk_4_1,
  wrapGAppsHook3,
  xdg-utils,
}:

let
  release = builtins.fromJSON (builtins.readFile releaseManifest);

  # The source follows upstream's main branch, so the version is the last tag
  # with the "-dirty" suffix upstream uses for a build from source.
  version = "${lib.removePrefix "v" release.tag_name}-dirty";
in
buildGoModule (finalAttrs: {
  pname = "magpie";
  inherit src version;

  __structuredAttrs = true;

  # go.sum has not changed since 0.1.1290; when it does, the build prints the new hash.
  vendorHash = "sha256-pBk3sQZ9/1sVdz2ZteBGgQrI49fDfgsQ8ur7pzM477A=";

  subPackages = [ "." ];

  # Nix-specific behaviour, see the patch: the package owns updates, magpie://
  # and the autostart entry.
  patches = [ ./nix-support.patch ];

  env.CGO_ENABLED = "1";

  # gtk3 is what upstream's Makefile picks on Linux: GTK 3 and WebKitGTK 4.1.
  tags = [
    "production"
    "gtk3"
  ];

  ldflags = [
    "-s"
    "-w"
    "-X=main.version=${finalAttrs.version}"
    "-X=github.com/yetone/magpie/internal/update.NixBuild=1"
  ];

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook3
    copyDesktopItems
  ];

  buildInputs = [
    gtk3
    webkitgtk_4_1
    # libsoup's HTTPS is the GIO TLS module; without it the window loads local
    # pages, then fails every remote image and request.
    glib-networking
  ];

  doCheck = false;

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

  postInstall = ''
    install -Dm644 internal/gui/icon-256.png \
      "$out/share/icons/hicolor/256x256/apps/magpie.png"
    install -Dm644 internal/gui/icon-1024.png \
      "$out/share/icons/hicolor/1024x1024/apps/magpie.png"
    install -Dm644 build/icon/magpie.svg \
      "$out/share/icons/hicolor/scalable/apps/magpie.svg"
    install -Dm644 LICENSE "$out/share/licenses/magpie/LICENSE"
  '';

  # wrapGAppsHook3 only collects gappsWrapperArgs; wrapping happens in postFixup.
  dontWrapGApps = true;

  postFixup = ''
    wrapProgram "$out/bin/magpie" "''${gappsWrapperArgs[@]}" \
      --prefix PATH : ${lib.makeBinPath [ xdg-utils ]} \
      --set MAGPIE_BUN ${lib.getExe bun}
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "Local gateway that picks the model for each AI coding agent";
    homepage = "https://usemagpie.ai/";
    changelog = "https://github.com/yetone/magpie/commits/main";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    platforms = [ "x86_64-linux" ];
  };
})
