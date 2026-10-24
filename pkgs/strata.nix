{
  lib,
  buildFHSEnv,
  fetchurl,
  runCommand,
  bash,
  bubblewrap,
  cairo,
  coreutils,
  desktop-file-utils,
  ffmpeg,
  ffmpegthumbnailer,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  glib-networking,
  graphene,
  gst_all_1,
  gtk4,
  gtksourceview5,
  harfbuzz,
  imagemagick,
  libjpeg_turbo,
  libpng,
  libraw,
  librsvg,
  pango,
  poppler,
  shared-mime-info,
  squashfs-tools,
  util-linux,
  xdg-terminal-exec,
  xdg-utils,
  releaseLib,
  releaseManifest,
  repoRoot,
}:

let
  manifest = releaseLib.readManifest releaseManifest;

  version = lib.removePrefix "v" manifest.tag;

  archive = "strata-${version}-x86_64-unknown-linux-gnu.tar.gz";

  artifact = lib.findFirst (
    entry: entry.name == archive
  ) (throw "strata: ${archive} is missing from the update manifest") manifest.artifacts;

  src = fetchurl {
    url = "https://github.com/lgse/strata/releases/download/v${version}/${archive}";
    hash = releaseLib.sri artifact.sha256;
  };

  runtimeTools = [
    bubblewrap
    coreutils
    desktop-file-utils
    ffmpeg
    ffmpegthumbnailer
    fontconfig
    gdk-pixbuf
    glib
    imagemagick
    libraw
    squashfs-tools
    util-linux
    xdg-utils
  ];

  sharedLibraries = [
    cairo
    freetype
    gdk-pixbuf
    glib
    graphene
    gtk4
    gtksourceview5
    harfbuzz
    libjpeg_turbo
    libpng
    pango
    poppler
    librsvg
  ];

  gstPlugins = with gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-libav
  ];

  # buildFHSEnv only mirrors bin/lib/share/etc out of each target package, so
  # the release archive is unpacked into that layout first.
  app = runCommand "strata-${version}-release" { } ''
    mkdir -p "$out/bin" "$out/share"
    tar -xzf ${src} --strip-components=1 -C "$out/share"
    mv "$out/share/strata" "$out/bin/strata"
    chmod +x "$out/bin/strata"
  '';
in
buildFHSEnv {
  pname = "strata";
  inherit version;

  runScript = "strata";
  executableName = "strata";

  targetPkgs =
    _:
    [ app ]
    ++ runtimeTools
    ++ sharedLibraries
    ++ gstPlugins
    ++ [
      glib-networking
      shared-mime-info
      xdg-terminal-exec
    ];

  # The release binary bakes in FHS sandbox defaults: PATH=/usr/bin and /usr as
  # its single system tree. Inside this rootfs /usr is a set of store symlinks,
  # so that sandbox also needs /nix/store. Strata launches bubblewrap from a
  # trusted host path and rejects store symlinks, so the mount is injected by
  # replacing the rootfs bwrap with a wrapper that appends it before argv's
  # `--` separator.
  extraBuildCommands = ''
    mv "$out/usr/bin/bwrap" "$out/usr/bin/bwrap-real"
    cat > "$out/usr/bin/bwrap" <<'EOF'
    #!${lib.getExe' bash "bash"}
    set -euo pipefail
    for arg in "$@"; do
      if [ "$arg" = "--" ]; then
        exec /usr/bin/bwrap-real --ro-bind /nix/store /nix/store "$@"
      fi
    done
    exec /usr/bin/bwrap-real "$@"
    EOF
    chmod +x "$out/usr/bin/bwrap"
  '';

  extraInstallCommands = ''
    documents=${app}/share

    install -Dm644 "$documents/io.github.lgse.Strata.desktop" \
      "$out/share/applications/io.github.lgse.Strata.desktop"
    substituteInPlace "$out/share/applications/io.github.lgse.Strata.desktop" \
      --replace-fail 'Exec=strata %U' "Exec=$out/bin/strata %U"

    install -Dm644 "$documents/io.github.lgse.Strata.svg" \
      "$out/share/icons/hicolor/scalable/apps/io.github.lgse.Strata.svg"

    install -Dm644 "$documents/io.github.lgse.Strata.FileManager1.service" \
      "$out/share/strata/io.github.lgse.Strata.FileManager1.service"
    substituteInPlace "$out/share/strata/io.github.lgse.Strata.FileManager1.service" \
      --replace-fail '/usr/bin/strata' "$out/bin/strata"

    install -Dm644 "$documents/portal/strata.portal" \
      "$out/share/xdg-desktop-portal/portals/strata.portal"
    install -Dm644 "$documents/portal/org.freedesktop.impl.portal.desktop.strata.service.in" \
      "$out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service"
    substituteInPlace "$out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service" \
      --replace-fail '@STRATA_EXECUTABLE@' "$out/bin/strata"

    install -Dm644 /dev/stdin "$out/share/strata/install-source.toml" <<'MARKER'
    manager = "Nix"
    package = "strata"
    channel = "stable"
    update_command = "cd ${lib.escapeShellArg repoRoot} && just update && nh os switch ${lib.escapeShellArg repoRoot}"
    MARKER

    install -Dm644 "$documents/LICENSE" "$out/share/licenses/strata/LICENSE"
    install -Dm644 "$documents/THIRD_PARTY_LICENSES.md" "$out/share/licenses/strata/THIRD_PARTY_LICENSES.md"
    install -Dm644 "$documents/UnRAR.txt" "$out/share/licenses/strata/UnRAR.txt"
  '';

  passthru = {
    inherit app version;
    unwrapped = app;
  };

  meta = {
    description = "Fast, keyboard-first file manager for Linux (official release)";
    homepage = "https://github.com/lgse/strata";
    changelog = "https://github.com/lgse/strata/releases/tag/v${version}";
    license = [
      lib.licenses.mit
      lib.licenses.unfree
    ];
    mainProgram = "strata";
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
