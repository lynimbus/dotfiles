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
  # The release archive holds the desktop entry, the app icon and the
  # libghostty-vt.so the editor's terminal panes run on; the Go build only
  # produces the binary. version, the archive hash and the source hash all
  # follow the release tag, so `just bump mayoi` (nix-update) moves them
  # together, the archive being its --custom-dep tarball.
  version ? "0.19.3",
  hash ? "sha256-daqMOiT17GNpF223FOBTFjrNYLfPMvJefLZEBXrICc0=",
  archiveSuffix ? "linux-amd64",
  archiveHash ? "sha256-erzbX+sHhYtPHsAwZVt2dEFZPkbtSkbKDeG0IcinwzI=",
  vendorHash ? "sha256-WaP7qWh7FCoVk8hrMiol4ap1a8j6zJ0uhxkM/62PqJQ=",
}:

let
  tarball = fetchurl {
    url = "https://github.com/sorrycc/Mayoi/releases/download/v${version}/mayoi-${version}-${archiveSuffix}.tar.gz";
    hash = archiveHash;
  };

  src = fetchFromGitHub {
    owner = "sorrycc";
    repo = "Mayoi";
    tag = "v${version}";
    inherit hash;
  };

  # mygo reaches every one of these through dlopen, so the binary names none
  # of them in DT_NEEDED and only an rpath entry makes the loader find them.
  # The editor also starts language servers from the login shell, which bring
  # their own.
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
  pname = "mayoi";
  inherit version;

  inherit src;

  # The editor is its own command, and the repository's root package is the
  # window around it, so the one program to install is ./cmd/mayoi.
  subPackages = [ "./cmd/mayoi" ];

  # A nix-managed app must not update itself: mygo compiles an updater in
  # only when `mygo build` embeds both a feed and a signing key from
  # mygo.json, and this plain `go build` embeds neither, so the store path is
  # the only mayoi there is. The identity flags keep settings, the recent
  # files and the plugin directory where the official build keeps them.
  ldflags = [
    "-s"
    "-w"
    "-X github.com/egoist/mygo.production=1"
    "-X github.com/egoist/mygo.packageName=Mayoi"
    "-X github.com/egoist/mygo.packageVersion=${version}"
    "-X github.com/egoist/mygo.packageIdentifier=dev.mayoi.editor"
  ];

  inherit vendorHash;

  # The tests open windows and wait on a terminal's libghostty-vt, and the
  # build tree carries neither: the checks stay off, and the display smoke
  # below covers the binary running at all.
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
    makeWrapper $out/lib/mayoi/mayoi $out/bin/mayoi "''${gappsWrapperArgs[@]}"
  '';

  # The app resolves its resources from the directory of its own executable:
  # the icon mygo shows for the window and the libghostty-vt.so every
  # terminal pane loads. Both are files of the release and not of the Go
  # build, so the archive supplies them.
  installPhase = ''
    runHook preInstall

    tar xf ${tarball} -C "$TMPDIR"

    mkdir -p $out/lib/mayoi
    install -Dm755 $GOPATH/bin/mayoi $out/lib/mayoi/mayoi
    cp -r "$TMPDIR"/icon.png "$TMPDIR"/mayoi.png "$TMPDIR"/libghostty-vt.so $out/lib/mayoi/

    install -Dm644 "$TMPDIR"/mayoi.png $out/share/icons/hicolor/1024x1024/apps/mayoi.png
    for size in 512 256; do
      magick "$TMPDIR"/mayoi.png -resize "''${size}x''${size}" "mayoi-''${size}.png"
      install -Dm644 "mayoi-''${size}.png" "$out/share/icons/hicolor/''${size}x''${size}/apps/mayoi.png"
    done

    install -Dm644 "$TMPDIR"/mayoi.desktop $out/share/applications/mayoi.desktop
    install -Dm644 ${src}/LICENSE $out/share/licenses/mayoi/LICENSE

    runHook postInstall
  '';

  # An argument is a file to open, so mayoi has no --version to ask, and
  # versionCheckHook would start the UI and hang. Without a display the app
  # stops with its own message instead, which still proves the binary runs
  # and that GTK, fontconfig and the rest resolved through the wrapper's rpath.
  doInstallCheck = true;

  installCheckPhase = ''
    runHook preInstallCheck

    output=$($out/bin/mayoi 2>&1 || true)
    case "$output" in
      *"cannot open display"*) ;;
      *)
        echo "mayoi did not start: $output" >&2
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
    description = "Code editor that draws its own UI on the GPU, with tabs, splits, plugins and a Vim mode";
    homepage = "https://github.com/sorrycc/Mayoi";
    changelog = "https://github.com/sorrycc/Mayoi/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "mayoi";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [
      lib.sourceTypes.fromSource
      lib.sourceTypes.binaryNativeCode
    ];
  };
}
