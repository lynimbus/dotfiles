{
  lib,
  stdenv,
  fetchurl,
  # The release tarball is the only source: `just bump rtk` (nix-update)
  # moves the version and its hash to the latest release together.
  version ? "1.1.0",
  hash ? "sha256-lFStG5SJ2qV6sKn06+L6r03IK4oPJsnlE1FRq9fJN40=",
  archiveSuffix ? "x86_64-unknown-linux-musl",
}:

let
  archive = "rtk-${archiveSuffix}.tar.gz";
in
stdenv.mkDerivation {
  pname = "rtk";
  inherit version;

  src = fetchurl {
    url = "https://github.com/rtk-ai/rtk/releases/download/v${version}/${archive}";
    inherit hash;
  };

  sourceRoot = ".";

  dontBuild = true;
  dontConfigure = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 rtk $out/bin/rtk
    install -Dm644 LICENSE $out/share/licenses/rtk/LICENSE
    install -Dm644 LICENSE-ENGINE $out/share/licenses/rtk/LICENSE-ENGINE

    runHook postInstall
  '';

  passthru = {
    inherit archiveSuffix;
  };

  meta = {
    description = "CLI proxy that shrinks the output of common dev commands before it reaches an LLM";
    homepage = "https://github.com/rtk-ai/rtk";
    changelog = "https://github.com/rtk-ai/rtk/releases/tag/v${version}";
    license = [
      lib.licenses.asl20
      lib.licenses.bsl11
    ];
    mainProgram = "rtk";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
