{
  lib,
  stdenv,
  fetchurl,
  # The release tarball is the only source: `just bump rtk` (nix-update)
  # moves the version and its hash to the latest release together.
  version ? "1.2.0",
  hash ? "sha256-cP7ntKVIxD3elMd+IzVVCYGwvC+wE2kdjIEJtb0O2jc=",
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

  passthru.bump = [ ];

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
