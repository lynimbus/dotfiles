{
  lib,
  stdenvNoCC,
  fetchurl,
  autoPatchelfHook,
  coreutils,
  glibc,
  libgcc,
  patchelfUnstable,
  versionCheckHook,
  # sing-box's unstable channel is upstream's GitHub prereleases (alpha/beta/rc
  # tags), and every tag carries prebuilt tarballs for each platform; this takes
  # the linux-amd64 one. Version and hashes are literals in this file, and
  # `just bump sing-box` (nix-update) rewrites them through the
  # legacyPackages attribute path. The channel is pinned to unstable by this
  # file's passthru.bump: --version=unstable lets prereleases past nix-update's
  # stable preference, and --version-regex keeps stable tags out so a bump
  # cannot drift to the stable channel (keeping v? inside the capture group so
  # nix-update's replace_version strips it without setting new_version.rev on a
  # fetchurl src). Those tags cover quic/dhcp/wireguard/clash_api/tailscale/
  # naive, more than nixpkgs or a source build of the flake offers. Note that
  # upstream's plain linux-amd64 build is dynamically linked PIE (its interpreter
  # points at /lib64/ld-linux) even though CGO is off, so it cannot run in the
  # sandbox: autoPatchelf replaces the interpreter, and appendRunpaths gives
  # every ELF library the glibc rpath, because the naive outbound dlopens the
  # bundled libcronet.so by the absolute path it finds (its NEEDED list also
  # holds libm and other glibc parts). The musl variant is fully static but has
  # no libcronet.so, which drops the naive outbound, so it is not used.
  #
  # patchelf 0.15.2's --set-rpath corrupts this ~79MB Go PIE binary (leaving it
  # segfaulting with no output); nixpkgs provides 0.19.x as patchelfUnstable,
  # put first on PATH in preFixup ahead of shrink-rpath and autoPatchelfHook.
  version ? "1.15.0-alpha.14",
  hash ? "sha256-2x4ZgiRKca9HjVnDGU3kRHxjDFT2oTCN8/W6e1sEtsg=",
}:

stdenvNoCC.mkDerivation {
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
    export PATH="${patchelfUnstable}/bin:$PATH"
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

        # Upstream's prebuilt tarball omits the systemd, D-Bus, and polkit assets
        # that NixOS's services.sing-box module expects via systemd.packages and
        # services.dbus.packages. Keep User=sing-box capabilities (which upstream
        # dropped in 1.15 when switching its own packages to root) because the
        # NixOS module still runs the service as the unprivileged sing-box user.
        install -Dm444 /dev/stdin $out/lib/systemd/system/sing-box.service <<'EOF'
    [Unit]
    Description=sing-box service
    Documentation=https://sing-box.sagernet.org
    After=network.target nss-lookup.target network-online.target

    [Service]
    User=sing-box
    StateDirectory=sing-box
    CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
    AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
    ExecStart=@out@/bin/sing-box -D /var/lib/sing-box -C /etc/sing-box run
    ExecReload=@coreutils@/bin/kill -HUP $MAINPID
    Restart=on-failure
    RestartSec=10s
    LimitNOFILE=infinity

    [Install]
    WantedBy=multi-user.target
    EOF

        install -Dm444 /dev/stdin $out/lib/systemd/system/sing-box@.service <<'EOF'
    [Unit]
    Description=sing-box service
    Documentation=https://sing-box.sagernet.org
    After=network.target nss-lookup.target network-online.target

    [Service]
    User=sing-box
    StateDirectory=sing-box-%i
    CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
    AmbientCapabilities=CAP_NET_ADMIN CAP_NET_RAW CAP_NET_BIND_SERVICE CAP_SYS_PTRACE CAP_DAC_READ_SEARCH
    ExecStart=@out@/bin/sing-box -D /var/lib/sing-box-%i -c /etc/sing-box/%i.json run
    ExecReload=@coreutils@/bin/kill -HUP $MAINPID
    Restart=on-failure
    RestartSec=10s
    LimitNOFILE=infinity

    [Install]
    WantedBy=multi-user.target
    EOF

        substituteInPlace $out/lib/systemd/system/sing-box{,@}.service \
          --replace-fail '@out@' "$out" \
          --replace-fail '@coreutils@' "${coreutils}"

        install -Dm444 /dev/stdin $out/share/polkit-1/rules.d/sing-box.rules <<'EOF'
    polkit.addRule(function(action, subject) {
        if ((action.id == "org.freedesktop.resolve1.set-domains" ||
             action.id == "org.freedesktop.resolve1.set-default-route" ||
             action.id == "org.freedesktop.resolve1.set-dns-servers") &&
            subject.user == "sing-box") {
            return polkit.Result.YES;
        }
    });
    EOF

        install -Dm444 /dev/stdin $out/share/dbus-1/system.d/sing-box-split-dns.conf <<'EOF'
    <!DOCTYPE busconfig PUBLIC
            "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
            "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
    <busconfig>
        <policy user="root">
            <allow own="org.freedesktop.resolve1"/>
            <allow send_destination="org.freedesktop.resolve1"/>
            <allow receive_sender="org.freedesktop.resolve1"/>
        </policy>
        <policy user="sing-box">
            <allow own="org.freedesktop.resolve1"/>
            <allow send_destination="org.freedesktop.resolve1"/>
            <allow receive_sender="org.freedesktop.resolve1"/>
        </policy>
    </busconfig>
    EOF

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
    "--version-regex=(v?\\d+\\.\\d+\\.\\d+-(?:alpha|beta|rc)\\.\\d+)"
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
