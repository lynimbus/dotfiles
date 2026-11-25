{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
  # The version and the archive hash come from the same release tag;
  # "just bump dolt" (nix-update) rewrites these literals together.
  version ? "2.7.7",
  hash ? "sha256-CH07yk+M3mEoG+5FH2AYv1L1Z0VPV4oUkznvkfRmvZI=",
}:

let
  # Dolthub publishes a binary per platform rather than a source archive, so
  # the asset name is the only per-system part. Anything but linux is an error
  # instead of a wrong download.
  asset =
    {
      x86_64-linux = "linux-amd64";
      aarch64-linux = "linux-arm64";
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "dolt: no release asset for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "dolt";
  inherit version;

  # The linux asset is statically linked, so it runs from the store as it is
  # and needs neither patchelf nor an ICU build input.
  src = fetchurl {
    url = "https://github.com/dolthub/dolt/releases/download/v${version}/dolt-${asset}.tar.gz";
    inherit hash;
  };

  sourceRoot = "dolt-${asset}";

  # The archive holds bin/dolt and one LICENSES file.
  installPhase = ''
    runHook preInstall
    install -Dm755 bin/dolt $out/bin/dolt
    install -Dm644 LICENSES $out/share/licenses/dolt/LICENSES
    runHook postInstall
  '';

  # dolt has no --version flag; its subcommand prints "dolt version 2.7.3".
  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];
  versionCheckProgram = "${placeholder "out"}/bin/dolt";
  versionCheckProgramArg = "version";

  # --build is what bump-packages.sh asks for on a release-asset package: a
  # fetchurl src carries no rev, so nix-update re-fetches on every run and only
  # the build proves the new hash and the version check.
  passthru.bump = [ "--build" ];

  meta = {
    description = "SQL database with Git-style versioning";
    homepage = "https://github.com/dolthub/dolt";
    license = lib.licenses.asl20;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "dolt";
  };
}
