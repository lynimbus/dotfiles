{
  lib,
  stdenv,
  fetchurl,
  releaseManifest,
  archiveSuffix ? "x86_64-unknown-linux-musl",
}:

let
  release = builtins.fromJSON (builtins.readFile releaseManifest);

  version = lib.removePrefix "v" release.tag_name;

  archive = "rtk-${archiveSuffix}.tar.gz";

  asset = lib.findFirst (
    entry: entry.name == archive
  ) (throw "rtk: release ${version} has no ${archive} asset") release.assets;
in
stdenv.mkDerivation {
  pname = "rtk";
  inherit version;

  src = fetchurl {
    url = asset.browser_download_url;
    hash = builtins.convertHash {
      hash = lib.removePrefix "sha256:" asset.digest;
      hashAlgo = "sha256";
      toHashFormat = "sri";
    };
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
