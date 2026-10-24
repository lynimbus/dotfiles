{
  lib,
  stdenv,
  fetchurl,
  releaseLib,
  releaseManifest,
  archiveSuffix ? "x86_64-unknown-linux-musl",
}:

let
  release = releaseLib.githubRelease {
    pname = "rtk";
    manifest = releaseManifest;
  };

  archive = "rtk-${archiveSuffix}.tar.gz";

  asset = release.asset archive;

  version = release.version;
in
stdenv.mkDerivation {
  pname = "rtk";
  inherit version;

  src = fetchurl {
    inherit (asset) url hash;
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
