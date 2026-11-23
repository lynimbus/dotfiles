# Shared builder for native Go desktop applications using github.com/egoist/mygo.
# Packages keep their own version/hash parameters and meta attrset so nix-update
# sees meta.position inside pkgs/<name>.nix.
{
  lib,
  buildGoModule,
  autoPatchelfHook,
  imagemagick,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  glib-networking,
  gtk-layer-shell,
  gtk3,
  harfbuzz,
  hicolor-icon-theme,
  libayatana-appindicator,
  libepoxy,
  libpulseaudio,
  libsecret,
  libx11,
  libxtst,
  pango,
  shared-mime-info,
  webkitgtk_4_1,
}:

let
  # MyGo loads GTK, WebKit, audio, and tray libraries via purego/dlopen rather
  # than DT_NEEDED, so they must live on the binary's rpath via runtimeDependencies.
  defaultRuntimeLibs = map lib.getLib [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    fontconfig
    freetype
    gdk-pixbuf
    glib
    glib-networking
    gtk-layer-shell
    gtk3
    harfbuzz
    hicolor-icon-theme
    libayatana-appindicator
    libepoxy
    libpulseaudio
    libsecret
    libx11
    libxtst
    pango
    shared-mime-info
    webkitgtk_4_1
  ];
in
{
  pname,
  version,
  src,
  vendorHash,
  packageName,
  packageIdentifier,
  subPackages ? [ "." ],
  extraLdflags ? [ ],
  runtimeLibs ? defaultRuntimeLibs,
  extraNativeBuildInputs ? [ ],
  tarball ? null,
  tarballResources ? [ ],
  displaySmokeCheck ? false,
  passthru ? { },
  ...
}@args:
let
  quotedPackageName =
    if lib.hasInfix " " packageName then
      "-X 'github.com/egoist/mygo.packageName=${packageName}'"
    else
      "-X github.com/egoist/mygo.packageName=${packageName}";

  passthroughArgs = builtins.removeAttrs args [
    "packageName"
    "packageIdentifier"
    "extraLdflags"
    "runtimeLibs"
    "extraNativeBuildInputs"
    "tarball"
    "tarballResources"
    "displaySmokeCheck"
    "passthru"
  ];

  tarballCopyArgs = lib.concatMapStringsSep " " (
    r: ''"$TMPDIR"/${lib.escapeShellArg r}''
  ) tarballResources;
in
buildGoModule (
  {
    inherit
      pname
      version
      src
      vendorHash
      subPackages
      ;

    # Plain `go build` without feed/signing-key flags disables MyGo's self-updater
    # while preserving upstream's production config and data directory names.
    ldflags = [
      "-s"
      "-w"
      "-X github.com/egoist/mygo.production=1"
      quotedPackageName
      "-X github.com/egoist/mygo.packageVersion=${version}"
      "-X github.com/egoist/mygo.packageIdentifier=${packageIdentifier}"
    ]
    ++ extraLdflags;

    nativeBuildInputs = [
      autoPatchelfHook
      makeWrapper
      wrapGAppsHook3
    ]
    ++ lib.optional (tarball != null) imagemagick
    ++ extraNativeBuildInputs;

    buildInputs = runtimeLibs;
    runtimeDependencies = runtimeLibs;

    # Wrap the executable in $out/lib/<pname>/<pname> so sibling assets stay
    # next to the real binary while $out/bin/<pname> carries GTK/GIO env vars.
    dontWrapGApps = true;

    preFixup = ''
      makeWrapper $out/lib/${pname}/${pname} $out/bin/${pname} "''${gappsWrapperArgs[@]}"
    '';

    passthru =
      lib.optionalAttrs (tarball != null) {
        inherit tarball;
        bump = [
          "--custom-dep"
          "tarball"
        ];
      }
      // passthru;
  }
  // lib.optionalAttrs (tarball != null) {
    installPhase = ''
      runHook preInstall

      tar xf ${tarball} -C "$TMPDIR"

      mkdir -p $out/lib/${pname}
      install -Dm755 $GOPATH/bin/${pname} $out/lib/${pname}/${pname}
      ${lib.optionalString (tarballResources != [ ]) ''
        cp -r ${tarballCopyArgs} $out/lib/${pname}/
      ''}

      install -Dm644 "$TMPDIR"/${pname}.png $out/share/icons/hicolor/1024x1024/apps/${pname}.png
      for size in 512 256; do
        magick "$TMPDIR"/${pname}.png -resize "''${size}x''${size}" "${pname}-''${size}.png"
        install -Dm644 "${pname}-''${size}.png" "$out/share/icons/hicolor/''${size}x''${size}/apps/${pname}.png"
      done

      install -Dm644 "$TMPDIR"/${pname}.desktop $out/share/applications/${pname}.desktop
      install -Dm644 ${src}/LICENSE $out/share/licenses/${pname}/LICENSE

      runHook postInstall
    '';
  }
  // lib.optionalAttrs displaySmokeCheck {
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck

      output=$(env -u DISPLAY -u WAYLAND_DISPLAY $out/bin/${pname} 2>&1 || true)
      case "$output" in
        *"cannot open display"*) ;;
        *)
          echo "${pname} did not start: $output" >&2
          exit 1
          ;;
      esac

      runHook postInstallCheck
    '';
  }
  // passthroughArgs
)
