{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
  # The release asset is the only source: `just bump opengrep` (nix-update)
  # moves the version and its hash to the latest release together.
  version ? "2.0.0",
  hash ? "sha256-N+k/TaX9BKGMXB/rvdEvfpjfzNTQyc8lk7yyXutGLaA=",
  # 1.33.1 called this asset opengrep_manylinux_x86, 2.0.0 renamed it to
  # opengrep_linux_x86; nix-update cannot see a rename, only a version, so
  # this follows the releases by hand.
  archiveSuffix ? "linux_x86",
}:

# Since 2.0.0 the asset is one statically linked executable (161 MB, no
# `.interp` section, `ldd` says "not a dynamic executable"): the embedded
# python runtime, the CLI and the OCaml matching core all live in that single
# file, so it runs as-is and nothing is unpacked, spawned or written outside
# the store. Up to 1.33.1 this was instead a Nuitka onefile launcher that
# unpacked ~240 MB of python world into ~/.cache/opengrep/<version> on first
# run, which had to be pre-unpacked at build time; if a future bump brings
# that shape back, `patchelf --print-interpreter` on the asset tells you
# immediately (`patchelf: cannot find section '.interp'` is the static case).
stdenvNoCC.mkDerivation {
  pname = "opengrep";
  inherit version;

  src = fetchurl {
    url = "https://github.com/opengrep/opengrep/releases/download/v${version}/opengrep_${archiveSuffix}";
    inherit hash;
  };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/opengrep"
    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.bump = [ "--build" ];

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
