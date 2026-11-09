{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  glibc,
  libgcc,
  patchelf,
  versionCheckHook,
  # sing-box's unstable channel is upstream's GitHub prereleases (alpha/beta/rc
  # tags), and every tag carries prebuilt tarballs for each platform; this takes
  # the linux-amd64 one. Version and hashes are literals in this file, and
  # `just bump sing-box` (nix-update) rewrites them through the
  # legacyPackages attribute path. The channel is pinned to unstable by this
  # file's passthru.bump: --version=unstable lets prereleases past nix-update's
  # stable preference, and its --version-regex capture group only matches
  # alpha/beta/rc tags while stripping the v prefix, so a bump cannot drift to
  # the stable channel. Those tags cover quic/dhcp/wireguard/clash_api/tailscale/
  # naive, more than nixpkgs or a source build of the flake offers. Note that
  # upstream's plain linux-amd64 build is dynamically linked PIE (its interpreter
  # points at /lib64/ld-linux) even though CGO is off, so it cannot run in the
  # sandbox: autoPatchelf replaces the interpreter, and appendRunpaths gives
  # every ELF library the glibc rpath, because the naive outbound dlopens the
  # bundled libcronet.so by the absolute path it finds (its NEEDED list also
  # holds libm and other glibc parts). The musl variant is fully static but has
  # no libcronet.so, which drops the naive outbound, so it is not used.
  #
  # A second patchelf, 0.19.2, is pinned below because nixpkgs reverted
  # "patchelf: 0.15.2 -> 0.19.2" in 61a15beb37 on 2026-10-30 (nixpkgs#577387,
  # the 26.11 freeze): the default patchelf went back to 0.15.2 and 0.19.x was
  # left as patchelfUnstable. 0.15.2's --set-rpath corrupts this ~79MB Go PIE
  # binary: --set-interpreter alone is fine, and a --set-rpath right after it
  # leaves the binary segfaulting with no output, while the same two steps with
  # 0.19.2 work (three years of ELF-rewriting fixes between 0.16 and 0.19.2).
  # auto-patchelf.py and patchelf's own shrink-rpath hook both resolve a bare
  # patchelf from PATH, and patchelf is not among autoPatchelfHook's inputs: it
  # arrives from stdenv's default nativeBuildInputs as 0.15.2. So 0.19.2 is
  # pinned as patchelf-0-19 and put first on PATH in preFixup. A corrupted binary
  # fails silently: versionCheckPhase gets empty output and reports "Did not find
  # version". Once nixpkgs defaults to a patchelf with the fix (or offers a
  # cleaner override point), this pin and the preFixup go away together.
  version ? "1.15.0-alpha.13",
  hash ? "sha256-v8OfZDpezBtwLFcj/2YuYd3oE/ErOvDQz85PYp/3QEc=",
}:

let
  # The expression nixpkgs had before the revert (a release tarball); the hash is
  # the sha256 of that download, as in that expression. The current nixpkgs
  # patchelf carries an empty patch list, so overrideAttrs needs nothing else.
  patchelf-0-19 = patchelf.overrideAttrs (old: rec {
    version = "0.19.2";
    src = fetchurl {
      url = "https://github.com/NixOS/patchelf/releases/download/${version}/patchelf-${version}.tar.bz2";
      hash = "sha256-1K2aTlxongkRnOLzCpSw6LT5jHhZASPqIWZeNMaSiAE=";
    };
  });
in

stdenv.mkDerivation {
  pname = "sing-box";
  inherit version;

  src = fetchurl {
    url = "https://github.com/SagerNet/sing-box/releases/download/v${version}/sing-box-${version}-linux-amd64.tar.gz";
    inherit hash;
  };

  sourceRoot = "sing-box-${version}-linux-amd64";

  nativeBuildInputs = [ autoPatchelfHook ];
  # libcronet.so needs libgcc_s on top of glibc. appendRunpaths is
  # autoPatchelfHook's own extension point and rewrites patchelf's rpath
  # wholesale, so a manual --add-rpath does not work (a postFixup string runs
  # before autoPatchelf).
  buildInputs = [
    glibc
    libgcc
  ];
  appendRunpaths = [ "${glibc}/lib" ];
  # patchelf's shrink-rpath hook and auto-patchelf.py both resolve patchelf by
  # bare name from PATH, where stdenv injects 0.15.2. preFixup is fixupPhase's
  # first hook, ahead of fixupOutputHooks' shrink-rpath and
  # autoPatchelfPostFixup, so putting the pinned 0.19.2 first on PATH here
  # covers the whole fixup.
  preFixup = ''
    export PATH="${patchelf-0-19}/bin:$PATH"
  '';

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # The tarball holds three things: the main binary, the LICENSE and
    # libcronet.so, the last two side by side. libcronet.so has to be installed
    # into bin next to the binary because cronet-go's loader_unix.go finds its
    # libraries itself at the Go level (the directory of os.Executable(), the
    # LD_LIBRARY_PATH segments, /usr/local/lib, /usr/lib) and dlopens whatever it
    # finds by absolute path through purego: it never consults the ELF RUNPATH
    # and has no variable of its own for the path. The executable's own directory
    # is the first, unconditional choice, which is upstream's tarball layout;
    # nothing but a naive outbound ever touches the file. The earlier
    # $out/lib + wrapper approach that set LD_LIBRARY_PATH was broken on this
    # machine: makeWrapper's --set-default only injects a value when the variable
    # is unset, and the login session here has LD_LIBRARY_PATH exported globally
    # by pipewire-jack, so the wrapper was silently ineffective and every naive
    # connection failed with "cronet: library not found".
    install -Dm755 sing-box $out/bin/sing-box
    install -Dm644 libcronet.so $out/bin/libcronet.so
    install -Dm644 LICENSE $out/share/licenses/sing-box/LICENSE

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  # sing-box has no global --version flag; the version comes from the
  # `sing-box version` subcommand.
  versionCheckProgramArg = "version";
  # The naive outbound loads the cronet engine when it is initialized, which the
  # check subcommand also reaches, so a minimal naive configuration runs the
  # whole dlopen path: versionCheck only compares the version string and would
  # not notice upstream renaming the library or changing the search order. The
  # build sandbox has no environment pollution, so an unrelated LD_LIBRARY_PATH
  # is set on purpose to reproduce a polluted real session: the exe-dir search
  # must ignore it to pass.
  postInstallCheck = ''
    printf '%s\n' '{"outbounds":[{"type":"naive","tag":"check","server":"127.0.0.1","server_port":443,"username":"u","password":"p","tls":{"enabled":true,"server_name":"example.com"}}]}' > naive-check.json
    LD_LIBRARY_PATH=/definitely/not/here $out/bin/sing-box check -c naive-check.json

    # Regression assertion: in the incident above, the bad patchelf (0.15.2's
    # --set-rpath) left the main binary segfaulting silently and
    # versionCheckPhase only reported "Did not find version"; finding patchelf
    # from that message took a whole round of debugging. Running the same call
    # versionCheckPhase makes, and asserting both the exit code and the version
    # string, points straight at ELF corruption when it happens again.
    if ! version_out=$(env --ignore-environment --chdir=/ \
        --argv0=sing-box "$out/bin/sing-box" version 2>&1); then
      echo "postInstallCheck: 'sing-box version' exited non-zero under a clean env — ELF most likely corrupted by a bad patchelf (see the patchelf-0-19 pin above):" >&2
      printf '%s\n' "$version_out" >&2
      exit 1
    fi
    if ! grep -Fq "sing-box version ${version}" <<< "$version_out"; then
      echo "postInstallCheck: expected 'sing-box version ${version}' in clean-env version output, got:" >&2
      printf '%s\n' "$version_out" >&2
      exit 1
    fi
  '';

  passthru.bump = [
    # The unstable channel is upstream's prerelease tags: --version=unstable
    # lets them past nix-update's stable preference and the regex keeps stable
    # tags out, so a bump cannot drift channels. --build reruns versionCheckHook
    # and the naive smoke check here rather than at switch time.
    "--version=unstable"
    "--version-regex=v?(\\d+\\.\\d+\\.\\d+-(?:alpha|beta|rc)\\.\\d+)"
    "--build"
  ];

  meta = {
    description = "Universal proxy platform (upstream unstable prerelease binaries)";
    homepage = "https://sing-box.sagernet.org";
    changelog = "https://github.com/SagerNet/sing-box/releases";
    license = lib.licenses.gpl3Only;
    mainProgram = "sing-box";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
