{
  lib,
  buildFHSEnv,
  fetchurl,
  writeShellScript,
  patchelf,
  binutils,
  glibc,
  gtk3,
  webkitgtk_4_1,
  glib,
  gdk-pixbuf,
  libsoup_3,
  libx11,
  glib-networking,
  gsettings-desktop-schemas,
  gst_all_1,
}:
let
  # This is only the bootstrap copy. Magpie replaces the writable copy itself.
  version = "0.1.745";
  src = fetchurl {
    url = "https://github.com/yetone/magpie-releases/releases/download/v${version}/magpie-linux-amd64";
    hash = "sha256-dlwCjEzgmbVRhiJVk1snC7y7oU76RMljHNkuNm3g1Qs=";
  };

  runtimePackages = [
    gtk3
    webkitgtk_4_1
    glib
    gdk-pixbuf
    libsoup_3
    libx11
    glib-networking
    gsettings-desktop-schemas
    gst_all_1.gst-plugins-base
  ];
  runtimeLibraryPath = lib.makeLibraryPath runtimePackages;
  bootstrap = writeShellScript "magpie-bootstrap" ''
    set -eu

    state_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/magpie"
    binary="$state_dir/bin/magpie"
    if [ ! -x "$binary" ]; then
      mkdir -p "$state_dir/bin"
      tmp="$binary.new.$$"
      install -m 0755 "${src}" "$tmp"
      if [ ! -x "$binary" ]; then
        mv -f "$tmp" "$binary"
      else
        rm -f "$tmp"
      fi
    fi

    # Self-updates install a generic Linux ELF. Re-attach the NixOS loader and
    # library paths so Magpie's own restart path can execute it outside the FHS
    # mount too.
    ${patchelf}/bin/patchelf \
      --set-interpreter ${glibc}/lib64/ld-linux-x86-64.so.2 \
      --set-rpath "${runtimeLibraryPath}" \
      "$binary"

    exec "$binary" "$@"
  '';
in
buildFHSEnv {
  pname = "magpie";
  inherit version;
  executableName = "magpie";

  targetPkgs = _pkgs: runtimePackages;
  runScript = bootstrap;
  profile = ''
    # Keep the self-updater's executable and the autostart record stable.
    export APPIMAGE="''${HOME}/.local/bin/magpie"
    export GSETTINGS_SCHEMA_DIR="${gsettings-desktop-schemas}/share/gsettings-schemas/gsettings-desktop-schemas-${lib.getVersion gsettings-desktop-schemas}/glib-2.0/schemas"
    export GDK_PIXBUF_MODULE_FILE="${gdk-pixbuf}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
    export GIO_EXTRA_MODULES="${glib-networking}/lib/gio/modules"
    export GST_PLUGIN_SYSTEM_PATH_1_0="${gst_all_1.gst-plugins-base}/lib/gstreamer-1.0"
  '';

  meta = {
    description = "Magpie AI model gateway in a self-updating FHS environment";
    homepage = "https://github.com/yetone/magpie";
    license = lib.licenses.mit;
    mainProgram = "magpie";
    platforms = [ "x86_64-linux" ];
  };
}
