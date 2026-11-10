{
  lib,
  fetchFromGitHub,
  fetchurl,
  buildGoModule,
  go_1_27,
  imagemagick,
  makeWrapper,
  wrapGAppsHook3,
  autoPatchelfHook,
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
  # The release archive holds the desktop entry and the app icon; the Go
  # build only produces the binary. version, the archive hash and the source
  # hash all follow the release tag, so `just bump mygo-music` (nix-update)
  # moves them together, the archive being its --custom-dep tarball.
  version ? "0.1.22",
  hash ? "sha256-Cgp1qLckpUTOJfY9PZzhcHqknjqjPIbGDAuCj1M03sk=",
  archiveSuffix ? "linux-amd64",
  archiveHash ? "sha256-dQcJQxO5fQPGq/nrRe+D3AFyLTZ/JC9Vz4T5EWJDtxo=",
  vendorHash ? "sha256-SHmrMG6tYzGSBhvLMdIikLonjeR3r7IOeJiaGE+srik=",
}:

let
  tarball = fetchurl {
    url = "https://github.com/egoist/mygo-music/releases/download/v${version}/mygo-music-${version}-${archiveSuffix}.tar.gz";
    hash = archiveHash;
  };

  src = fetchFromGitHub {
    owner = "egoist";
    repo = "mygo-music";
    tag = "v${version}";
    inherit hash;
  };

  # mygo reaches every one of these through dlopen, so the binary names none
  # of them in DT_NEEDED and only an rpath entry makes the loader find them.
  # The sound goes through PulseAudio's simple API and falls back to ALSA;
  # the rest is the UI, the tray and the secrets store.
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
  pname = "mygo-music";
  inherit version;

  inherit src;

  # The app is the root package. Its plugins are separate processes, which
  # the app starts from its own login shell, so the binary is the whole Go
  # build.
  subPackages = [ "." ];

  # A nix-managed app must not update itself: mygo compiles an updater in
  # only when `mygo build` embeds both a feed and a signing key from
  # mygo.config.ts, and this plain `go build` embeds neither, so the store
  # path is the only mygo-music there is. The identity flags keep settings,
  # the library database and the sherpa-onnx download cache where the
  # official build keeps them, since the app names those paths after them.
  ldflags = [
    "-s"
    "-w"
    "-X github.com/egoist/mygo.production=1"
    # mygo quotes a value with a space the way its own `mygo build` does, and
    # buildGoModule joins these flags into one -ldflags string, which go's
    # linker splits again on quotes. Without them the name splits in two.
    "-X 'github.com/egoist/mygo.packageName=MyGo Music'"
    "-X github.com/egoist/mygo.packageVersion=${version}"
    "-X github.com/egoist/mygo.packageIdentifier=dev.egoist.music"
  ];

  inherit vendorHash;

  # The tests play audio files and decode artwork, and the checks build tree
  # carries neither the release's icon nor a sound device: the checks stay
  # off, and the version smoke below covers the binary running at all.
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
    makeWrapper $out/lib/mygo-music/mygo-music $out/bin/mygo-music "''${gappsWrapperArgs[@]}"
  '';

  # The app resolves the icon mygo shows for the window from the directory of
  # its own executable. It is a file of the release and not of the Go build,
  # so the archive still supplies it.
  installPhase = ''
    runHook preInstall

    tar xf ${tarball} -C "$TMPDIR"

    mkdir -p $out/lib/mygo-music
    install -Dm755 $GOPATH/bin/mygo-music $out/lib/mygo-music/mygo-music
    cp -r "$TMPDIR"/icon.png "$TMPDIR"/mygo-music.png $out/lib/mygo-music/

    install -Dm644 "$TMPDIR"/mygo-music.png $out/share/icons/hicolor/1024x1024/apps/mygo-music.png
    for size in 512 256; do
      magick "$TMPDIR"/mygo-music.png -resize "''${size}x''${size}" "mygo-music-''${size}.png"
      install -Dm644 "mygo-music-''${size}.png" "$out/share/icons/hicolor/''${size}x''${size}/apps/mygo-music.png"
    done

    install -Dm644 "$TMPDIR"/mygo-music.desktop $out/share/applications/mygo-music.desktop
    install -Dm644 ${src}/LICENSE $out/share/licenses/mygo-music/LICENSE

    runHook postInstall
  '';

  # An argument is a file to open, so mygo-music has no --version to ask, and
  # versionCheckHook would start the UI and hang. Without a display the app
  # stops with its own message instead, which still proves the binary runs
  # and that GTK, fontconfig and the rest resolved through the wrapper's rpath.
  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck

    output=$($out/bin/mygo-music 2>&1 || true)
    case "$output" in
      *"cannot open display"*) ;;
      *)
        echo "mygo-music did not start: $output" >&2
        exit 1
        ;;
    esac

    runHook postInstallCheck
  '';

  passthru = {
    # nix-update's --custom-dep tarball rewrites the archive hash beside the
    # source hash in the same file, so one bump moves the whole release.
    inherit tarball;

    bump = [
      "--custom-dep"
      "tarball"
    ];
  };

  meta = {
    description = "Native music player for your own files and the streaming accounts you sign in to";
    homepage = "https://github.com/egoist/mygo-music";
    changelog = "https://github.com/egoist/mygo-music/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "mygo-music";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryNativeCode
    ];
  };
}
