{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  patchelf,
  versionCheckHook,
  zlib,
  releaseLib,
  releaseManifest,
  archiveSuffix ? "manylinux_x86",
}:

let
  release = releaseLib.githubRelease {
    pname = "opengrep";
    manifest = releaseManifest;
  };

  version = release.version;

  # The "single binary" is a Nuitka onefile launcher: on first run it unpacks a
  # whole python world (~240 MB: the compiled CLI `opengrep.bin`, the C
  # extension modules and the vendored .so libraries) into a fixed directory
  # ~/.cache/opengrep/<version> and execs the inner binary from there. The
  # unpack is done once at build time instead, so the store path holds the
  # payload and nothing is ever unpacked or written at run time (verified
  # read-only: the inner binary only reads its tree).
  #
  # The launcher and the inner binary are both linked against plain glibc with
  # the FHS interpreter /lib64/ld-linux-x86-64.so.2, so both are pointed at
  # the stdenv loader here. The payload's own libraries live beside the
  # binaries and are found through $ORIGIN rpaths, with one exception: the
  # stdlib's binascii.so NEEDs libz.so.1, which the payload does not ship —
  # on a normal distro /lib/libz.so.1 exists and hides this, on NixOS its
  # absence makes the codecs registry fail to register hex_codec and every
  # invocation dies with "LookupError: unknown encoding: hex_codec". The
  # wrapper puts nix zlib on LD_LIBRARY_PATH to close exactly that gap.
  #
  # The musllinux asset needs a musl interpreter and buys nothing here, so
  # the glibc (manylinux) asset is the one pinned.
  asset = release.asset "opengrep_${archiveSuffix}";

  payloadRoot = "share/opengrep";
in
stdenv.mkDerivation {
  pname = "opengrep";
  inherit version;

  src = fetchurl {
    inherit (asset) url hash;
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  nativeBuildInputs = [
    patchelf
    makeWrapper
  ];

  installPhase = ''
    runHook preInstall

    launcher="$TMPDIR/opengrep-launcher"
    install -Dm755 "$src" "$launcher"
    patchelf --set-interpreter \
      "${stdenv.cc.bintools.dynamicLinker}" "$launcher"

    # The launcher unpacks into $HOME/.cache/opengrep/<version> and then
    # execs the payload binary, which fails harmlessly (exit 0, the unpack
    # stays on disk) because its own interpreter is still the FHS one —
    # the point here is only to produce the unpack.
    unpack_home="$TMPDIR/unpack-home"
    mkdir -p "$unpack_home"
    HOME="$unpack_home" "$launcher" --version >/dev/null 2>&1 || true

    # The unpack directory is named after the release tag, v-prefixed.
    payload="$unpack_home/.cache/opengrep/v${version}"
    if [ ! -x "$payload/opengrep.bin" ]; then
      echo "opengrep: the launcher did not unpack the payload into $payload" >&2
      find "$unpack_home" -maxdepth 6 -name opengrep.bin -print >&2
      exit 1
    fi

    mkdir -p "$out/${payloadRoot}"
    cp -a "$payload"/. "$out/${payloadRoot}/"
    # The launcher unpacks with owner-only modes (0700 directories), which
    # would keep every other account out of the store tree.
    chmod -R u+w "$out/${payloadRoot}"
    chmod -R a+rX "$out/${payloadRoot}"
    patchelf --set-interpreter \
      "${stdenv.cc.bintools.dynamicLinker}" \
      "$out/${payloadRoot}/opengrep.bin"

    # opengrep-core is a static OCaml binary the CLI spawns for the actual
    # matching; it needs no patching, it is copied as part of the payload.

    makeWrapper "$out/${payloadRoot}/opengrep.bin" "$out/bin/opengrep" \
      --prefix LD_LIBRARY_PATH : "${lib.getLib zlib}/lib"

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru = {
    inherit archiveSuffix;
  };

  meta = {
    description = "Open-source static analysis engine (Semgrep fork) with no login and no telemetry";
    homepage = "https://github.com/opengrep/opengrep";
    changelog = "https://github.com/opengrep/opengrep/releases/tag/v${version}";
    license = lib.licenses.lgpl21;
    mainProgram = "opengrep";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
