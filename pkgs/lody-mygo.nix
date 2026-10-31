{
  lib,
  buildGoModule,
  fetchFromGitHub,
  fetchurl,
  go_1_27,
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
  # The release tag is the only version there is (mygo.json's version must
  # match it), so `just bump lody-mygo` (nix-update) moves the version, the
  # source hash and the vendorHash in lockstep.
  version ? "0.1.1",
  hash ? "sha256-Z0HRO2F95EjKHeod8FPLvwhSnOJ4ZO/chNhu1EzCwQs=",
  vendorHash ? "sha256-YHudMhez0e+NLwugUxmOAYooeqwJIHkPgwR9BndFseo=",
  # libghostty-vt is a prebuilt the terminal plugin of mygo (the pinned
  # dependency, not this repo) publishes under its own release, so this
  # fetchurl of its own travels beside the Go source. Its URL and hash are
  # vendored inside mygo's plugins/terminal/mygo-plugin.json, which
  # nix-update cannot read: when a bump moves the mygo pin in go.mod (the
  # vendorHash changing is the signal), move these two by hand, from that
  # file's linux-amd64 entry. A stale library still loads -- the app checks
  # the checksum only of one it downloads itself, into its cache -- but a
  # too-old one can grow incompatible with the bindings, so keep them close.
  ghosttyVtUrl ? "https://github.com/egoist/mygo/releases/download/libghostty-vt-befcdfd2c3a1/libghostty-vt-linux-amd64.so",
  ghosttyVtHash ? "sha256-nc2K8N5nd4pWH0NstnOp+xc4vo+gCEna1JYGuu0eV9c=",
}:

let
  src = fetchFromGitHub {
    owner = "lbr77";
    repo = "lody-mygo";
    tag = "v${version}";
    inherit hash;
  };

  ghosttyVt = fetchurl {
    url = ghosttyVtUrl;
    hash = ghosttyVtHash;
  };

  # Upstream calls itself macOS-only, but the app is plain mygo native UI:
  # every dlopen below is one mygo's Linux backend makes, and loro-go
  # ships prebuilt static libraries for linux-amd64 too, so the source
  # builds and runs here the same way kero's does.
  #
  # The app reaches every one of these through dlopen, so the binary names
  # none of them in DT_NEEDED and only an rpath entry makes the loader find
  # them. The default output of glib, pango and fontconfig is not the one
  # holding the libraries, so take each package's lib output.
  runtimeLibs = map lib.getLib [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cairo
    fontconfig
    freetype
    gdk-pixbuf
    glib
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
  ];
in
(buildGoModule.override { go = go_1_27; }) {
  pname = "lody-mygo";
  inherit version;

  inherit src;

  # The app is the root package; mygo and everything else are libraries.
  subPackages = [ "." ];

  # A nix-managed app must not update itself, and this plain `go build`
  # embeds neither an updater feed nor its signing key, so the store path is
  # the only lody-mygo there is and upgrades belong to the rebuild. The
  # identity flags are what `mygo build` links in from mygo.json, so
  # settings and deep links (lody:) land where the official build keeps
  # them.
  ldflags = [
    "-s"
    "-w"
    "-X github.com/egoist/mygo.production=1"
    "-X \"github.com/egoist/mygo.packageName=Lody Native\""
    "-X github.com/egoist/mygo.packageVersion=${version}"
    "-X github.com/egoist/mygo.packageIdentifier=dev.libr.lody-native"
    "-X github.com/egoist/mygo.packageURLSchemes=lody"
  ];

  inherit vendorHash;

  # go mod vendor copies source files only, which drops loro-go's
  # prebuilt libs/*.a its cgo LDFLAGS point into; the module cache the
  # proxy keeps them, so build against that instead of a vendor tree
  # (and the vendorHash above is the hash of the cache).
  proxyVendor = true;

  # loro-go links its vendored Rust static library through cgo, which
  # buildGoModule turns off only when cross-compiling: this pin keeps it on
  # whatever a future default does.
  env.CGO_ENABLED = 1;

  # The UI tests render offscreen through the very dlopens the sandbox
  # environment has none of, and the check phase has no display either;
  # the version smoke below covers the binary running at all.
  doCheck = false;

  nativeBuildInputs = [
    autoPatchelfHook
    imagemagick
    makeWrapper
    wrapGAppsHook3
  ];

  # The rpath the dlopen'd libraries are found through.
  runtimeDependencies = runtimeLibs;

  # GTK and the pixbuf loaders are opened from the store by name, so the
  # schemas, the loader cache and the TLS GIO module need the environment
  # a wrapped GTK app gets. The hook fills gappsWrapperArgs in preFixup and
  # would wrap $out/bin, which is why it wraps the executable in lib instead.
  dontWrapGApps = true;

  # The app resolves its resources from the directory of its own
  # executable: the window icon it draws and the libghostty-vt.so it loads
  # for every embedded terminal. They are files mygo build puts beside the
  # binary of an official build, so this build supplies them.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/lody-mygo $out/bin
    cp $GOPATH/bin/lody-mygo $out/lib/lody-mygo/lody-mygo
    cp ${ghosttyVt} $out/lib/lody-mygo/libghostty-vt.so
    cp ${src}/icon.png $out/lib/lody-mygo/icon.png
    cp ${src}/icon.png $out/lib/lody-mygo/lody-mygo.png

    mkdir -p $out/share/applications $out/share/icons/hicolor
    for size in 16 32 48 64 128 256 512; do
      mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
      convert ${src}/icon.png -background none -resize ''${size}x''${size} \
        $out/share/icons/hicolor/''${size}x''${size}/apps/lody-mygo.png
    done
    # What `mygo build` writes for a Linux app (cmd/mygo/build.go,
    # linuxDesktopEntry): the launcher shows the name, the deep links run
    # the Exec, the icon comes from hicolor.
    cat > $out/share/applications/lody-mygo.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Name=Lody Native
    Exec=lody-mygo %U
    Icon=lody-mygo
    Categories=Utility;
    Terminal=false
    MimeType=x-scheme-handler/lody;
    EOF

    mkdir -p $out/share/licenses/lody-mygo
    cp ${src}/LICENSE $out/share/licenses/lody-mygo/LICENSE

    runHook postInstall
  '';

  preFixup = ''
    makeWrapper $out/lib/lody-mygo/lody-mygo $out/bin/lody-mygo "''${gappsWrapperArgs[@]}"
  '';

  doInstallCheck = true;
  # versionCheckHook would ask --version, which the framework answers only
  # after opening a display (kero handles the flag before Init; lody does
  # not), so the smoke is two things a sandbox can do: the identity flags
  # this build links, and a run that fails at the display -- Backend.Init
  # dlopens the whole GTK stack before it asks for the display, so reaching
  # that error carries the binary past every library it loads at startup.
  installCheckPhase = ''
    runHook preInstallCheck

    grep -aF "Lody Native" $out/lib/lody-mygo/lody-mygo >/dev/null
    err=$($out/bin/lody-mygo --version 2>&1 || true)
    if [[ "$err" != *"cannot open display"* ]]; then
      echo "unexpected output of a displayless run: $err" >&2
      exit 1
    fi

    runHook postInstallCheck
  '';

  passthru = {
    inherit ghosttyVt;
  };

  meta = {
    description = "Native desktop client for Lody, drawn on the GPU without a web view";
    homepage = "https://github.com/lbr77/lody-mygo";
    changelog = "https://github.com/lbr77/lody-mygo/releases/tag/v${version}";
    license = lib.licenses.agpl3Only;
    mainProgram = "lody-mygo";
    platforms = [ "x86_64-linux" ];
    # loro-go vendors prebuilt Rust static libraries, and libghostty-vt is
    # a prebuilt of mygo's.
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
