{
  lib,
  stdenv,
  stdenvNoCC,
  fetchurl,
  unzip,
  autoPatchelfHook,
  patchelfUnstable,
  makeWrapper,
  wrapGAppsHook3,
  alsa-lib,
  cairo,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  glib-networking,
  gst_all_1,
  gtk3,
  webkitgtk_4_1,
  harfbuzz,
  hicolor-icon-theme,
  libayatana-appindicator,
  libdrm,
  libepoxy,
  libgcc,
  libpulseaudio,
  libsecret,
  libsoup_3,
  libx11,
  libxcb,
  libxkbcommon,
  mesa,
  pango,
  shared-mime-info,
  # The release archive is the only source: it carries the native shell, the
  # node server with its prebuilt native modules, and the renderer bundle, none
  # of which is built here. Version and hash are the two literals `just bump
  # alma` (nix-update) moves to the latest release together.
  version ? "0.4.1179",
  hash ? "sha256-eEd96PQV1CAlv60Fl+R45kqTh3nFczv3m3SKRK9LsLc=",
}:

let
  archive = "alma-${version}-linux-x64.zip";

  src = fetchurl {
    url = "https://github.com/yetone/alma-releases/releases/download/v${version}/${archive}";
    inherit hash;
  };

  # The release's two big binaries need different patchelf: 0.15.2 writes a
  # --set-rpath into the ~77MB Go shell that leaves it dying with SIGSEGV,
  # while patchelfUnstable (0.19.x) rewrites it cleanly; on the ~121MB node
  # runtime it is the other way round. Both are invoked explicitly in postFixup.
  # The damage is silent, which is why the install check below is not optional.

  # The shell reaches GTK, WebKit and libsecret through cgo, so those land in
  # DT_NEEDED and autoPatchelfHook resolves them from buildInputs. The node
  # server and its native modules reach the rest the same way; the libraries
  # below are what the app links or dlopen's by bare name, and every one of
  # them also has to be on the rpath for the dlopen half.
  runtimeLibs = map lib.getLib [
    alsa-lib
    cairo
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    webkitgtk_4_1
    harfbuzz
    hicolor-icon-theme
    libayatana-appindicator
    libepoxy
    libsecret
    libsoup_3
    pango
    shared-mime-info
    # libstdc++ and libgomp for the node runtime and its native modules.
    stdenv.cc.cc.lib
  ];

  # WebKit plays media through GStreamer, which it finds through the plugin
  # path rather than through a NEEDED entry.
  gstPlugins = with gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-libav
  ];
in
stdenvNoCC.mkDerivation {
  pname = "alma";
  inherit version src;

  # The zip holds one top-level `Alma` directory with the release's layout,
  # the same files the .deb installs under /opt/alma.
  sourceRoot = "Alma";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    unzip
    wrapGAppsHook3
  ];

  # WebKit's compositor is the reason for the second list: it reaches GL, DRM,
  # Wayland and X11 by name from the renderer process, and which of them it
  # asks for depends on the session it starts in, so the rpath carries both
  # stacks while the shell itself names only the GTK one.
  buildInputs =
    runtimeLibs
    ++ gstPlugins
    ++ [
      # WebKit's HTTPS stack finds the GIO TLS module this carries.
      glib-networking
      libdrm
      libgcc
      libpulseaudio
      libx11
      libxcb
      libxkbcommon
      mesa
    ];

  # GTK, WebKit and the pixbuf loaders are opened with a bare dlopen from the
  # shell, so they never reach DT_NEEDED and only the rpath makes the loader
  # find them; autoPatchelfHook writes that rpath from this list.
  runtimeDependencies = runtimeLibs;

  # Two of the ws addons ship a musl build beside the glibc one; the loader
  # never picks the musl file here, and its interpreter is not in the closure.
  autoPatchelfIgnoreMissingDeps = [ "libc.musl-x86_64.so.1" ];

  # The release ships no source and nothing is compiled, so there is nothing to
  # configure or build; the unpacked tree is installed as it is.
  dontConfigure = true;
  dontBuild = true;

  # The app resolves its resources from the directory of its own executable:
  # renderer/ (the UI bundle), alma-server/ (the node server, its node_modules
  # and the bun/uv/rtk/whisper binaries it spawns) and the icons mygo draws the
  # window with. They are files of the release, not of a build, so they are
  # installed beside the binary rather than wrapped in a data path.
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/alma
    install -Dm755 alma $out/lib/alma/alma
    cp -r alma-server renderer $out/lib/alma/

    # The app's own updater would download a release and rewrite the files
    # under $out, which the store does not allow and which a rebuild has to do
    # anyway. Without the feed file the update check stays off.
    rm -f $out/lib/alma/app-update.yml

    install -Dm644 alma.desktop $out/share/applications/alma.desktop
    install -Dm644 alma.png $out/share/icons/hicolor/512x512/apps/alma.png
    install -Dm644 alma-256x256.png $out/share/icons/hicolor/256x256/apps/alma.png
    install -Dm644 THIRD_PARTY_NOTICES.md $out/share/licenses/alma/THIRD_PARTY_NOTICES.md

    runHook postInstall
  '';

  # GTK, WebKit and the pixbuf loaders are opened from the store by name, so the
  # schemas, the loader cache and the TLS GIO module need the environment a
  # wrapped GTK app gets. The hook fills gappsWrapperArgs in preFixup and would
  # wrap $out/bin, which is why it wraps the executable in lib instead.
  dontWrapGApps = true;

  # A GUI app that writes ~/.local/bin/alma for itself on first start is
  # installing the command this package already puts in $out/bin, so the shim
  # is told not to; ALMA_FA6_NO_CLI is the switch the shell reads for it.
  preFixup = ''
    makeWrapper $out/lib/alma/alma $out/bin/alma \
      "''${gappsWrapperArgs[@]}" \
      --set ALMA_FA6_NO_CLI 1
  '';

  # The patch order is the point: one autoPatchelf with stdenv's 0.15.2 covers
  # the node runtime, the native modules and the bun/uv/rtk/whisper binaries it
  # spawns, and then the shell is put back from the unpacked release and
  # patched again with 0.19.2. Letting the hook run on its own would leave the
  # shell corrupted, because a postFixup of this derivation is read before the
  # hook's own entry in postFixupHooks.
  dontAutoPatchelf = true;

  postFixup = ''
    autoPatchelf -- $out

    install -Dm755 "$NIX_BUILD_TOP/$sourceRoot/alma" $out/lib/alma/alma
    PATH=${patchelfUnstable}/bin:$PATH autoPatchelf --no-recurse -- $out/lib/alma/alma
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    # The node runtime the server is: this is where a corrupted patch of the
    # release's 121MB node binary shows up first.
    $out/lib/alma/alma-server/runtime/alma-server --version | grep -q '^v'

    # The shell dlopen's GTK through its rpath before it looks at the display,
    # and a corrupted patch of the other big binary dies silently instead.
    # Being told there is no display is the pass.
    export HOME=$TMPDIR/home
    mkdir -p "$HOME"
    out=$(DISPLAY= WAYLAND_DISPLAY= $out/bin/alma --version 2>&1 || true)
    grep -q 'cannot open display' <<<"$out"

    runHook postInstallCheck
  '';

  passthru.bump = [ "--build" ];

  meta = {
    description = "Agent harness and GUI client for herdr, Claude Code, Codex and pi";
    homepage = "https://alma.now";
    changelog = "https://github.com/yetone/alma-releases/releases/tag/v${version}";
    # The download is free but the app itself ships under a custom licence with
    # no source, so nixpkgs has no free licence to name.
    license = lib.licenses.unfree;
    mainProgram = "alma";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
