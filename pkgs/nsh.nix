{
  lib,
  stdenv,
  rustPlatform,
  runCommand,
  fetchFromGitHub,
  makeWrapper,
  wrapGAppsHook3,
  pkg-config,
  llvmPackages,
  # The libraries the Linux runtime (the GTK development host and the release
  # runner) links, and that an app's own Rust runner compiles against through
  # pkg-config. The GTK crates resolve every -sys dependency here (glib, pango,
  # cairo, soup, javascriptcore...) through the same chain, via each package's
  # propagated .pc files.
  gtk4,
  webkitgtk_6_0,
  glib,
  oniguruma,
  gst_all_1,
  gdk-pixbuf,
  shared-mime-info,
  gsettings-desktop-schemas,
  # Rust the launcher falls back to when the app builds its own runner and no
  # cargo is on PATH (rustup wins if it is; the runner build of an app with
  # Rust code calls cargo). Everything the build resolves is in this list, so
  # the fallback works without a dev shell.
  rustc,
  cargo,
  version ? "0.5.1",
  rev ? "224d9a795c7ac9d10d75750de9351adac5549675",
  hash ? "sha256-x+Iv+o94CsQMU2RXku9H300howJK0/NsnvHghNwnVIY=",
  cargoHash ? "sha256-+jOPlbdMo+MetT7oMkwn5MTvSfeDseLgKrh+52HzQb8=",
}:

let
  # The environment `nsh` builds a Rust app's runner in, captured as plain
  # store paths. The setup hooks of a plain derivation (pkg-config's, the
  # gsettings one) accumulate exactly the values a nix dev shell would export,
  # so the launcher reproduces them outside any shell: PKG_CONFIG_PATH for the
  # GTK/WebKit/GStreamer crates, the gsettings schemas for the runner binary,
  # and the GStreamer plugin path for the sound feature.
  runnerEnv =
    runCommand "nsh-runner-env"
      {
        nativeBuildInputs = [ pkg-config ];
        buildInputs = [
          gtk4
          webkitgtk_6_0
          glib
          oniguruma
          gst_all_1.gstreamer
          gst_all_1.gst-plugins-base
          gdk-pixbuf
          shared-mime-info
          gsettings-desktop-schemas
        ];
      }
      ''
        printf '%s\n' \
          "$PKG_CONFIG_PATH" \
          "$GSETTINGS_SCHEMAS_PATH" \
          "$GST_PLUGIN_SYSTEM_PATH_1_0" \
          > $out
      '';

  # The distribution: the CLI and this machine's runtimes, in the layout
  # `cargo xtask dist` produces and the CLI discovers (../../runtime from
  # bin/nsh).
  distribution = rustPlatform.buildRustPackage (finalAttrs: {
    pname = "nsh-distribution";
    inherit version;

    src = fetchFromGitHub {
      owner = "longbridge";
      repo = "nsh";
      rev = "v${version}";
      inherit hash;
      # The build script stamps the CLI with the checkout's revision, falling
      # back to the crates.io-style marker a packaged crate carries. A GitHub
      # archive has no .git, so that marker is written here; postFetch runs
      # after the tree has been moved to $out, hence the absolute path.
      postFetch = ''
        mkdir -p "$out/crates/nsh-cli"
        printf '{"git":{"sha1":"${rev}"}}' > "$out/crates/nsh-cli/.cargo_vcs_info.json"
      '';
    };

    # What `cargo xtask dist` builds for a Linux host: the CLI, the GTK
    # development host, the release runner, and the terminal host (`nsh run
    # --target tui`). The web and Android runtimes are components the CLI
    # downloads into the writable mirror on first use instead (the web one
    # needs a wasm32-targeting clang, the Android one an NDK).
    cargoBuildFlags = [
      "-p"
      "nsh-cli"
      "-p"
      "nsh-linux-host"
      "-p"
      "nsh-linux-app"
      "-p"
      "nsh-tui-host"
    ];

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit (finalAttrs) src;
      hash = cargoHash;
    };

    env.LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";

    nativeBuildInputs = [
      pkg-config
      makeWrapper
      wrapGAppsHook3
    ];

    buildInputs = [
      gtk4
      webkitgtk_6_0
      glib
      oniguruma
      gst_all_1.gstreamer
      gst_all_1.gst-plugins-base
    ];

    # The workspace's tests are a `nsh test` suite of their own, not cargo's.
    doCheck = false;

    # wrapGAppsHook wraps $out/bin by default, which holds only the mirrored
    # CLI here; the GTK host and the release runner are wrapped by hand.
    dontWrapGApps = true;

    installPhase = ''
      runHook preInstall

      # buildRustPackage compiles with `--target <triple>`, so the binaries
      # sit one directory deeper than the profile: target/<triple>/release/.
      rel="target/${stdenv.hostPlatform.rust.rustcTarget}/release"
      dist="$out/dist/nsh"
      mkdir -p "$dist/bin" "$dist/runtime/linux" "$dist/runtime/tui"
      cp "$rel/nsh" "$dist/bin/nsh"
      cp "$rel/nsh-linux-host" "$rel/nsh-linux-app" "$dist/runtime/linux/"
      cp "$rel/nsh-tui-host" "$dist/runtime/tui/"

      runHook postInstall
    '';

    # The hosts link GTK and WebKit at run time and read gsettings schemas and
    # GStreamer plugins from the environment; these wrappers carry both.
    postFixup = ''
      for exe in "$out/dist/nsh/runtime/linux/nsh-linux-host" "$out/dist/nsh/runtime/linux/nsh-linux-app"; do
        wrapProgram "$exe" \
          "''${gappsWrapperArgs[@]}" \
          --set GST_PLUGIN_SYSTEM_PATH_1_0 "${gst_all_1.gstreamer}/lib/gstreamer-1.0:${gst_all_1.gst-plugins-base}/lib/gstreamer-1.0"
      done
    '';

    meta = {
      description = "nsh distribution: the CLI and this machine's runtimes";
      homepage = "https://nsh.dev";
      license = lib.licenses.asl20;
      platforms = lib.platforms.linux;
    };
  });
in
# The `nsh` on PATH. This is a derivation of its own, separate from the
# distribution above, because it is the part that changes while the package is
# being written (the mirror logic, the environment the runner build needs). A
# change here rebuilds in seconds; only a version or dependency change pays for
# the distribution's compile.
runCommand "nsh-${version}"
  {
    passthru = {
      inherit distribution runnerEnv;
    };

    meta = distribution.meta // {
      mainProgram = "nsh";
    };
  }
  ''
    mkdir -p $out/bin
    # @dist@ is the distribution's own store path, not a symlink to it: the
    # launcher mirrors it with `cp -a`, which would copy a symlink as a
    # symlink and leave the mirror dangling.
    substitute ${./nsh-launcher.sh} $out/bin/nsh \
      --subst-var-by dist "${distribution}/dist/nsh" \
      --subst-var-by runnerEnv "${runnerEnv}" \
      --subst-var-by libclang "${llvmPackages.libclang.lib}/lib" \
      --subst-var-by toolPath "${lib.getBin pkg-config}/bin:${lib.getBin llvmPackages.clang}/bin" \
      --subst-var-by cargoPath "${lib.getBin cargo}/bin"
    chmod +x $out/bin/nsh
  ''
