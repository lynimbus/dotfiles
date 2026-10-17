{
  lib,
  rustPlatform,
  pkg-config,
  wrapGAppsHook4,
  glib,
  gtk4,
  gtksourceview5,
  poppler,
  fontconfig,
  gdk-pixbuf,
  gst_all_1,
  bubblewrap,
  util-linux,
  bash,
  coreutils,
  xdg-utils,
  ffmpeg,
  ffmpegthumbnailer,
  imagemagick,
  squashfsTools,
  runCommand,
  src,
}:

let
  version = (builtins.fromTOML (builtins.readFile "${src}/Cargo.toml")).package.version;

  sandboxTools = [
    bash
    coreutils
    util-linux
    ffmpeg
    ffmpegthumbnailer
    imagemagick
    squashfsTools
    fontconfig
  ];

  trustedTools = [
    bubblewrap
    bash
    coreutils
    xdg-utils
  ];

  gstPlugins = with gst_all_1; [
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-libav
  ];
in
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "strata";
  version = version;

  inherit src;

  # The lockfile ships no git dependencies, so vendoring needs no outputHashes.
  cargoLock.lockFile = "${src}/Cargo.lock";

  env = {
    STRATA_BUILD_COMMIT = finalAttrs.src.rev or "";
    STRATA_RELEASE_TAG = "v${version}";
    STRATA_BUILD_KIND = "stable";
    STRATA_SANDBOX_ROOT = "/nix/store";
    STRATA_SANDBOX_PATH = lib.makeBinPath sandboxTools;
    STRATA_SANDBOX_PRLIMIT = lib.getExe' util-linux "prlimit";
    STRATA_SANDBOX_GDK_PIXBUF_MODULE_FILE = "${gdk-pixbuf}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
  };

  postPatch =
    let
      profileRoot = ''"/run/current-system/profile/bin",'';
      extraRoots = lib.concatMapStringsSep "\n" (pkg: ''"${lib.getBin pkg}/bin",'') trustedTools;
    in
    ''
      substituteInPlace src/trusted_command.rs \
        --replace-fail ${lib.escapeShellArg profileRoot} ${lib.escapeShellArg "${profileRoot}\n${extraRoots}"}
    '';

  nativeBuildInputs = [
    pkg-config
    glib
    wrapGAppsHook4
  ];

  buildInputs = [
    gtk4
    gtksourceview5
    poppler
    fontconfig
    gdk-pixbuf
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
  ]
  ++ gstPlugins;

  preFixup = ''
    gappsWrapperArgs+=(--prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${lib.makeSearchPath "lib/gstreamer-1.0" gstPlugins}")
  '';

  postInstall = ''
    install -Dm644 data/io.github.lgse.Strata.desktop \
      "$out/share/applications/io.github.lgse.Strata.desktop"
    substituteInPlace "$out/share/applications/io.github.lgse.Strata.desktop" \
      --replace-fail 'Exec=strata %U' "Exec=$out/bin/strata %U"

    install -Dm644 data/icons/scalable/apps/io.github.lgse.Strata.svg \
      "$out/share/icons/hicolor/scalable/apps/io.github.lgse.Strata.svg"

    install -Dm644 data/io.github.lgse.Strata.FileManager1.service \
      "$out/share/strata/io.github.lgse.Strata.FileManager1.service"
    substituteInPlace "$out/share/strata/io.github.lgse.Strata.FileManager1.service" \
      --replace-fail '/usr/bin/strata' "$out/bin/strata"

    install -Dm644 data/portal/strata.portal \
      "$out/share/xdg-desktop-portal/portals/strata.portal"
    install -Dm644 data/portal/org.freedesktop.impl.portal.desktop.strata.service.in \
      "$out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service"
    substituteInPlace "$out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service" \
      --replace-fail '@STRATA_EXECUTABLE@' "$out/bin/strata"

    install -Dm644 /dev/stdin "$out/share/strata/install-source.toml" <<'MARKER'
    manager = "Nix"
    package = "strata"
    channel = "stable"
    MARKER

    install -Dm644 LICENSE "$out/share/licenses/strata/LICENSE"
    install -Dm644 THIRD_PARTY_LICENSES.md "$out/share/licenses/strata/THIRD_PARTY_LICENSES.md"
    cp -r data/licenses "$out/share/licenses/strata/third-party"
  '';

  doCheck = false;

  passthru.tests.version = runCommand "strata-version-check" { } ''
    ${finalAttrs.finalPackage}/bin/strata --version | tee "$out"
    grep -Fx 'strata ${version}' "$out"
  '';

  meta = {
    description = "Fast, keyboard-first file manager for Linux";
    homepage = "https://github.com/lgse/strata";
    changelog = "https://github.com/lgse/strata/releases/tag/v${version}";
    license = [
      lib.licenses.mit
      lib.licenses.unfree
    ];
    mainProgram = "strata";
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.fromSource ];
  };
})
