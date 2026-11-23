{
  lib,
  stdenvNoCC,
  fetchurl,
  versionCheckHook,
  # The release tarball is the only source: `just bump rtk` (nix-update)
  # moves the version and its hash to the latest release together.
  #
  # Only the stable line is tracked. Upstream's release bot publishes a
  # dev-1.3.0-rc.<n> prerelease on every merge, and those fill the whole ten
  # entries of releases.atom, so the newest stable tag is never in the feed;
  # the feed also carries no prerelease flag (nix-update's github.py has a
  # 'TODO: set pre-release flag' on exactly that), so nix-update called every
  # entry unstable and died in VersionError without writing anything.
  # --use-github-releases reads the releases API instead: it marks each release
  # with its prerelease flag, so the stable preference drops the dev tags, and
  # it pages until a short page, so the whole history is enumerated (5 pages,
  # ~500 releases on 2026-11-18) and v1.x is found however far the dev tags
  # push it down. That paging only stops early at nix-update's
  # --github-releases-limit of 1000 releases, which is where the dev flood
  # would break the bump again. Not --version=unstable a la sing-box: the dev
  # channel is an rc of the next minor and not what runs here.
  version ? "1.2.1",
  hash ? "sha256-dfZFJXEb6TVlemsijZKcJL2dGrfWQOo3SouRPltbrAU=",
  archiveSuffix ? "x86_64-unknown-linux-musl",
}:

let
  archive = "rtk-${archiveSuffix}.tar.gz";
in
stdenvNoCC.mkDerivation {
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

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.bump = [
    "--use-github-releases"
    "--build"
  ];

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
