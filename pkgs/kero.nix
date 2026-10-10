{
  lib,
  fetchFromGitHub,
  buildGoModule,
  go_1_27,
  autoPatchelfHook,
  imagemagick,
  makeWrapper,
  versionCheckHook,
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
  fetchurl,
  # The release archive is the only source of the fonts, the icons,
  # kero.desktop and libghostty-vt.so the app loads at run time, so it is a
  # fetchurl of its own beside the Go source. The version, the archive hash
  # and the source hash are functions of the release tag alone: `just bump
  # kero` (nix-update) moves them in lockstep, and the archive is the
  # `--custom-dep tarball` of that run.
  version ? "2.1.31",
  hash ? "sha256-lhCdEPCuBkPWZznIeSoFPxfhxqjEt3uC6xPjWXRdrEg=",
  archiveSuffix ? "linux-amd64",
  archiveHash ? "sha256-peiEdxTdTeYBNEV0JWe7QUJt9G2pE5MRxdRcCWuDUhE=",
  vendorHash ? "sha256-KiVj3Neaot04qgHKP1XDhuxK8jlK7ALkmSSdBRqjRV4=",
}:

let
  tarball = fetchurl {
    url = "https://github.com/egoist/kero/releases/download/v${version}/kero-${version}-${archiveSuffix}.tar.gz";
    hash = archiveHash;
  };

  # The Go code is fetched from the release tag.
  src = fetchFromGitHub {
    owner = "egoist";
    repo = "kero";
    tag = "v${version}";
    inherit hash;
  };

  # kero reaches every one of these through dlopen, so the binary names none
  # of them in DT_NEEDED and only an rpath entry makes the loader find them.
  # The default output of glib, pango and fontconfig is not the one holding
  # the libraries, so take each package's lib output.
  runtimeLibs = map lib.getLib [
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
(buildGoModule.override { go = go_1_27; }) {
  pname = "kero";
  inherit version;

  inherit src;

  # The app is the root package: mygo is a module of its own, and
  # ./cmd/kero-server is the server's own program.
  subPackages = [ "." ];

  # A nix-managed app must not update itself. MyGo compiles an updater in
  # only when `mygo build` embeds both a feed and a signing key from
  # mygo.json; this plain `go build` embeds neither, so the store path is
  # the only kero there is, and upgrades belong to the rebuild. The
  # identity flags keep settings and data where the official build keeps
  # them.
  ldflags = [
    "-s"
    "-w"
    "-X github.com/egoist/mygo.production=1"
    "-X github.com/egoist/mygo.packageName=Kero"
    "-X github.com/egoist/mygo.packageVersion=${version}"
    "-X github.com/egoist/mygo.packageIdentifier=sh.kero"
  ];

  inherit vendorHash;

  # Kero's tests want the release's libghostty-vt.so and fonts beside the
  # binary they run, and the build tree has neither: the checks stay off,
  # and the version smoke below covers the binary running at all.
  doCheck = false;

  nativeBuildInputs = [
    autoPatchelfHook
    imagemagick
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = runtimeLibs;

  # The rpath the dlopen'd libraries are found through.
  runtimeDependencies = runtimeLibs;

  # GTK, WebKit and the pixbuf loaders are opened from the store by name, so
  # the schemas, the loader cache and the TLS GIO module need the environment
  # a wrapped GTK app gets. The hook fills gappsWrapperArgs in preFixup and
  # would wrap $out/bin, which is why it wraps the executable in lib instead.
  dontWrapGApps = true;

  preFixup = ''
    makeWrapper $out/lib/kero/kero $out/bin/kero "''${gappsWrapperArgs[@]}"
  '';

  # The app resolves its resources from the directory of its own executable:
  # the fonts it draws with, the app icon mygo shows the window, and the
  # libghostty-vt.so it loads for every pane's terminal. They are files of
  # the release and not of the Go build, so it still supplies them.
  installPhase = ''
    runHook preInstall

    tar xf ${tarball} -C "$TMPDIR"

    mkdir -p $out/lib/kero
    install -Dm755 $GOPATH/bin/kero $out/lib/kero/kero
    cp -r "$TMPDIR"/fonts "$TMPDIR"/icon.png "$TMPDIR"/kero.png \
      "$TMPDIR"/libghostty-vt.so $out/lib/kero/

    install -Dm644 "$TMPDIR"/kero.png $out/share/icons/hicolor/1024x1024/apps/kero.png
    for size in 512 256; do
      magick "$TMPDIR"/kero.png -resize "''${size}x''${size}" "kero-''${size}.png"
      install -Dm644 "kero-''${size}.png" "$out/share/icons/hicolor/''${size}x''${size}/apps/kero.png"
    done

    install -Dm644 "$TMPDIR"/kero.desktop $out/share/applications/kero.desktop
    install -Dm644 ${src}/LICENSE $out/share/licenses/kero/LICENSE

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    # nix-update's --custom-dep tarball rewrites the archive hash beside the
    # source hash in the same file, so one bump moves the whole release.
    inherit tarball;
  };

  meta = {
    description = "Native terminal for coding agents, whose sessions outlive the window";
    homepage = "https://github.com/egoist/kero";
    changelog = "https://github.com/egoist/kero/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "kero";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryNativeCode
    ];
  };
}
